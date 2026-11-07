//! Sending to a conversation: messages with text, attachments and quotes,
//! reactions, and deletions ("delete for everyone").

use presage::libsignal_service::content::DataMessage;
use presage::proto::data_message::{quote, Delete, Quote, Reaction};
use presage::store::ContentsStore;
use serde_json::{json, Value};

use crate::commands::{now_millis, QuoteRequest};
use crate::convert;
use crate::events::{add_quote, files_json, StoredFile};
use crate::files;
use crate::outgoing;
use crate::receipts;
use crate::receiver::ATTACHMENT_PREVIEW;
use crate::threads::parse_thread_key;
use crate::titles::SignalManager;
use crate::worker::{threads_event, Shared};

pub async fn send(
    manager: &mut SignalManager,
    shared: &Shared,
    key: &str,
    text: String,
    paths: &[String],
    voice: bool,
    quote: Option<QuoteRequest>,
) {
    let fail = |message: String| {
        shared.sink.emit(json!({ "ev": "error", "action": "send", "kind": "other",
                                 "thread": key, "message": message }));
    };
    let Some(thread) = parse_thread_key(key) else {
        return fail("invalid conversation".into());
    };
    let uploads = match files::read_for_upload(paths, voice) {
        Ok(uploads) => uploads,
        Err(error) => return fail(error),
    };
    // Kept to store our own copy once the message is sent.
    let copies: Vec<_> =
        uploads.iter().map(|(spec, data)| (spec.content_type.clone(), data.clone())).collect();
    let pointers = match manager.upload_attachments(uploads).await {
        Ok(results) => match results.into_iter().collect::<Result<Vec<_>, _>>() {
            Ok(pointers) => pointers,
            Err(error) => return fail(error.to_string()),
        },
        Err(error) => return fail(error.to_string()),
    };
    let ts = now_millis();
    let own = manager.registration_data().service_ids.aci().service_id_string();
    let message = DataMessage {
        body: (!text.is_empty()).then(|| text.clone()),
        attachments: pointers,
        timestamp: Some(ts),
        quote: quote.as_ref().map(|q| Quote {
            id: Some(q.ts),
            author_aci: Some(if q.author.is_empty() { own.clone() } else { q.author.clone() }),
            text: (!q.text.is_empty()).then(|| q.text.clone()),
            r#type: Some(quote::Type::Normal as i32),
            ..Default::default()
        }),
        ..Default::default()
    };
    if let Err(error) = outgoing::deliver(manager, &thread, message, ts).await {
        return fail(error);
    }
    let stored = files::keep_sent(&shared.attachments_dir, ts, &copies);
    let preview = if text.is_empty() { ATTACHMENT_PREVIEW } else { &text };
    shared.index.borrow_mut().record(key, "", preview, ts, false);
    shared.receipts.borrow_mut().raise(ts, receipts::SENT);
    let mut event = sent_event(key, &text, ts, &stored);
    if let Some(q) = &quote {
        add_quote(&mut event, &q.text, &q.name, q.author.is_empty() || q.author == own);
    }
    shared.sink.emit(event);
    shared.sink.emit(threads_event(shared));
}

fn sent_event(key: &str, text: &str, ts: u64, stored: &[StoredFile]) -> Value {
    json!({ "ev": "sent", "thread": key, "outgoing": true, "sender": "", "senderName": "",
            "text": text, "ts": ts, "attachments": files_json(stored),
            "status": receipts::SENT })
}

/// Deletes a message from this phone; with `everyone`, first sends Signal's
/// delete request to the conversation, which also blanks the stored copy.
pub async fn delete_message(
    manager: &mut SignalManager,
    shared: &Shared,
    key: &str,
    ts: u64,
    everyone: bool,
) {
    let Some(thread) = parse_thread_key(key) else {
        return shared.sink.error("deleteMessage", "invalid conversation");
    };
    if everyone {
        let now = now_millis();
        let request = DataMessage {
            delete: Some(Delete { target_sent_timestamp: Some(ts) }),
            timestamp: Some(now),
            ..Default::default()
        };
        if let Err(error) = outgoing::deliver(manager, &thread, request, now).await {
            return shared.sink.error("deleteMessage", error);
        }
    }
    let mut store = manager.store().clone();
    if let Err(error) = store.delete_message(&thread, ts).await {
        return shared.sink.error("deleteMessage", error);
    }
    files::remove(&shared.attachments_dir, ts);
    forget_message(shared, key, ts);
}

/// Removes a deleted message from the app: the open chat and the preview in
/// the conversation list.
pub fn forget_message(shared: &Shared, key: &str, ts: u64) {
    shared.index.borrow_mut().forget_preview(key, ts);
    shared.sink.emit(json!({ "ev": "deleted", "thread": key, "ts": ts }));
    shared.sink.emit(threads_event(shared));
}

pub async fn react(
    manager: &mut SignalManager,
    shared: &Shared,
    key: &str,
    ts: u64,
    author: &str,
    emoji: &str,
    remove: bool,
) {
    let Some(thread) = parse_thread_key(key) else {
        return shared.sink.error("react", "invalid conversation");
    };
    let own = manager.registration_data().service_ids.aci().service_id_string();
    let now = now_millis();
    let message = DataMessage {
        reaction: Some(Reaction {
            emoji: Some(emoji.to_owned()),
            remove: Some(remove),
            target_author_aci: Some(if author.is_empty() { own } else { author.to_owned() }),
            target_sent_timestamp: Some(ts),
            ..Default::default()
        }),
        timestamp: Some(now),
        ..Default::default()
    };
    if let Err(error) = outgoing::deliver(manager, &thread, message, now).await {
        return shared.sink.error("react", error);
    }
    shared.sink.emit(crate::receiver::reaction_event(&convert::ReactionView {
        thread,
        target: ts,
        reactor: convert::ME.to_owned(),
        emoji: emoji.to_owned(),
        remove,
    }));
}
