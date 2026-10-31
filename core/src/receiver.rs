//! Receive loop: keeps the Signal message connection open, reconnecting with
//! a growing delay, and turns incoming messages into "message" events.

use std::rc::Rc;
use std::time::Duration;

use futures::{pin_mut, StreamExt};
use presage::libsignal_service::content::Content;
use presage::libsignal_service::protocol::ServiceId;
use presage::model::messages::Received;

use crate::convert;
use crate::events::{message_json, State};
use crate::files;
use crate::threads::thread_key;
use crate::titles::{self, SignalManager};
use crate::worker::Shared;

const FIRST_RETRY: Duration = Duration::from_secs(5);
const LAST_RETRY: Duration = Duration::from_secs(300);

/// Shown in the conversation list for messages that only carry attachments.
pub const ATTACHMENT_PREVIEW: &str = "📎";

pub async fn receive_loop(mut manager: SignalManager, shared: Rc<Shared>) {
    let own: ServiceId = manager.registration_data().service_ids.aci().into();
    let phone = manager.registration_data().phone_number.to_string();
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
    shared: &Shared,
    content: &Content,
    own: &ServiceId,
) {
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

    let mut event = message_json(&view, &key, &sender_name, &stored);
    event["ev"] = "message".into();
    event["title"] = shared.index.borrow().title(&key).unwrap_or_default().into();
    shared.sink.emit(event);
    shared.sink.emit(crate::worker::threads_event(shared));
}
