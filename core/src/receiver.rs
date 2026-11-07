//! Receive loop: keeps the Signal message connection open, reconnecting with
//! a growing delay, and turns incoming messages into "message" events.

use std::rc::Rc;
use std::time::Duration;

use futures::{pin_mut, StreamExt};
use presage::libsignal_service::content::{Content, ContentBody};
use presage::libsignal_service::protocol::ServiceId;
use presage::model::messages::Received;
use presage::proto::receipt_message::Type as ReceiptType;
use presage::proto::ReceiptMessage;

use crate::calls;
use crate::commands;
use crate::convert;
use crate::merge;
use crate::receipts;
use crate::events::{message_json, State};
use crate::files;
use crate::threads::thread_key;
use presage::store::Thread;
use crate::titles::{self, SignalManager};
use crate::worker::Shared;

const FIRST_RETRY: Duration = Duration::from_secs(5);
const LAST_RETRY: Duration = Duration::from_secs(300);

/// Shown in the conversation list for messages that only carry attachments.
pub const ATTACHMENT_PREVIEW: &str = "📎";

pub async fn receive_loop(mut manager: SignalManager, shared: Rc<Shared>) {
    let own: ServiceId = manager.registration_data().service_ids.aci().into();
    let phone = manager.registration_data().phone_number.to_string();
    merge::merge_duplicates(&mut manager, &shared).await;
    let mut retry = FIRST_RETRY;
    loop {
        match manager.receive_messages().await {
            Ok(messages) => {
                pin_mut!(messages);
                while let Some(received) = messages.next().await {
                    match received {
                        Received::QueueEmpty => {
                            shared.sink.state(State::Online, &phone);
                            retry = FIRST_RETRY;
                        }
                        Received::Content(content) => {
                            on_content(&mut manager, &shared, &content, &own).await
                        }
                        Received::Contacts => {}
                        Received::DecryptionError(sender) => tracing::warn!(
                            sender = sender.service_id_string(),
                            "could not decrypt a message"
                        ),
                    }
                }
            }
            Err(error) => shared.sink.error("receive", error),
        }
        shared.sink.state(State::Offline, &phone);
        tokio::time::sleep(retry).await;
        retry = (retry * 2).min(LAST_RETRY);
    }
}

async fn on_content(
    manager: &mut SignalManager,
    shared: &Rc<Shared>,
    content: &Content,
    own: &ServiceId,
) {
    // A reply that proves the sender owns the phone number identity we
    // wrote to: join the two chats before showing anything.
    if let Some(pni) = content.metadata.pni_verified {
        let pni = ServiceId::from(pni);
        if shared.index.borrow().is_open_chat(&thread_key(&Thread::Contact(pni))) {
            merge::merge_pni_thread(manager, shared, pni, content.metadata.sender).await;
        }
    }
    if let ContentBody::CallMessage(call) = &content.body {
        return calls::on_call_message(manager, shared, content, call).await;
    }
    if let ContentBody::ReceiptMessage(receipt) = &content.body {
        return on_receipt(shared, receipt);
    }
    if let Some(reaction) = convert::reaction(content, own) {
        return shared.sink.emit(reaction_event(&reaction));
    }
    if let Some((thread, ts)) = convert::deletion(content) {
        return crate::messaging::forget_message(shared, &thread_key(&thread), ts);
    }
    if let Some(edit) = convert::edit(content) {
        let key = thread_key(&edit.thread);
        shared.index.borrow_mut().update_preview(&key, edit.target, &edit.text);
        shared.sink.emit(serde_json::json!({ "ev": "edited", "thread": key,
                                             "target": edit.target, "text": edit.text }));
        return shared.sink.emit(crate::worker::threads_event(shared));
    }
    let Some(view) = convert::view(content, own) else {
        return;
    };
    let key = thread_key(&view.thread);
    let title = titles::thread_title(manager, &view.thread).await;
    let sender_name = if view.outgoing {
        String::new()
    } else {
        titles::contact_name(manager, &view.sender).await
    };
    let stored = files::download(manager, &shared.attachments_dir, &view).await;
    let preview = if view.text.is_empty() { ATTACHMENT_PREVIEW } else { &view.text };
    shared.index.borrow_mut().record(&key, &title, preview, view.ts, !view.outgoing);

    let quote_name = match view.quote.as_ref().and_then(|q| q.author.filter(|_| !q.own)) {
        Some(author) => titles::contact_name(manager, &author).await,
        None => String::new(),
    };
    let mut event = message_json(&view, &key, &sender_name, &quote_name, &stored);
    event["ev"] = "message".into();
    event["title"] = shared.index.borrow().title(&key).unwrap_or_default().into();
    shared.sink.emit(event);
    shared.sink.emit(crate::worker::threads_event(shared));
    // A first message from someone we wrote to by phone number.
    merge::merge_duplicates(manager, shared).await;

    if !view.outgoing {
        shared.unread.borrow_mut().entry(key).or_default().push((view.sender, view.ts));
        // The sender's app shows two ticks once a device of ours has it.
        let delivered = vec![(view.sender, view.ts)];
        commands::send_receipts(manager, delivered, ReceiptType::Delivery).await;
    }
}

/// A recipient's device got or showed some of our messages.
fn on_receipt(shared: &Shared, receipt: &ReceiptMessage) {
    let status = receipts::status_of(receipt.r#type);
    let changed: Vec<u64> = receipt
        .timestamp
        .iter()
        .copied()
        .filter(|ts| shared.receipts.borrow_mut().raise(*ts, status))
        .collect();
    if !changed.is_empty() {
        shared.sink.emit(serde_json::json!({ "ev": "receipt", "ts": changed, "status": status }));
    }
}

pub fn reaction_event(reaction: &convert::ReactionView) -> serde_json::Value {
    serde_json::json!({ "ev": "reaction", "thread": thread_key(&reaction.thread),
                        "target": reaction.target, "reactor": reaction.reactor,
                        "emoji": reaction.emoji, "remove": reaction.remove })
}
