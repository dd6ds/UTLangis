//! Sending to a conversation, and changing a sent message ("edit").

use presage::libsignal_service::content::{ContentBody, DataMessage, GroupContextV2};
use presage::proto::EditMessage;
use presage::store::{ContentsStore, Thread};
use serde_json::json;

use crate::convert;
use crate::threads::parse_thread_key;
use crate::titles::SignalManager;
use crate::worker::Shared;

/// Signal's apps refuse edits of messages older than this.
const EDIT_WINDOW_MS: u64 = 24 * 60 * 60 * 1000;

/// Sends a message (or edit, reaction, deletion) to a one-to-one chat or a
/// group. Group messages carry the group's key, which tells the recipients'
/// apps to file them in the group chat and not in a chat with the sender.
pub async fn deliver(
    manager: &mut SignalManager,
    thread: &Thread,
    body: impl Into<ContentBody>,
    ts: u64,
) -> Result<(), String> {
    let mut body = body.into();
    let result = match thread {
        Thread::Contact(id) => manager.send_message(*id, body, ts).await,
        Thread::Group(master_key) => {
            if let Some(data) = data_of(&mut body) {
                data.group_v2.get_or_insert_with(|| GroupContextV2 {
                    master_key: Some(master_key.to_vec()),
                    revision: Some(0),
                    ..Default::default()
                });
            }
            manager.send_message_to_group(master_key, body, ts).await
        }
    };
    result.map_err(|e| e.to_string())
}

fn data_of(body: &mut ContentBody) -> Option<&mut DataMessage> {
    match body {
        ContentBody::DataMessage(data) => Some(data),
        ContentBody::EditMessage(EditMessage { data_message: Some(data), .. }) => Some(data),
        _ => None,
    }
}

/// Changes the text of our message sent at `ts`. Signal sends the whole
/// message again, so its attachments and quote are taken over from the
/// stored original.
pub async fn edit_message(
    manager: &mut SignalManager,
    shared: &Shared,
    key: &str,
    ts: u64,
    text: &str,
) {
    let fail = |message: String| shared.sink.error("editMessage", message);
    let Some(thread) = parse_thread_key(key) else {
        return fail("invalid conversation".into());
    };
    let now = crate::commands::now_millis();
    if now.saturating_sub(ts) > EDIT_WINDOW_MS {
        return shared.sink.error_kind("editMessage", "editTooOld", "message too old to edit");
    }
    let original = match manager.store().message(&thread, ts).await {
        Ok(Some(content)) => content,
        Ok(None) => return fail("message not found".into()),
        Err(error) => return fail(error.to_string()),
    };
    let own = manager.registration_data().service_ids.aci().into();
    let is_own = convert::view(&original, &own).is_some_and(|v| v.outgoing);
    let Some(sent) = convert::data(&original).filter(|_| is_own) else {
        return fail("only own messages can be changed".into());
    };
    let data = DataMessage {
        body: Some(text.to_owned()),
        attachments: sent.attachments.clone(),
        quote: sent.quote.clone(),
        timestamp: Some(now),
        ..Default::default()
    };
    let edit = EditMessage { target_sent_timestamp: Some(ts), data_message: Some(data) };
    if let Err(error) = deliver(manager, &thread, edit, now).await {
        return fail(error);
    }
    shared.index.borrow_mut().update_preview(key, ts, text);
    shared.sink.emit(json!({ "ev": "edited", "thread": key, "target": ts, "text": text }));
    shared.sink.emit(crate::worker::threads_event(shared));
}
