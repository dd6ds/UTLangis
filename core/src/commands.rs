//! Commands from the app, and the ones that need a registered account.

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use presage::libsignal_service::content::DataMessage;
use presage::proto::data_message::Delete;
use presage::libsignal_service::prelude::phonenumber::{self, PhoneNumber};
use presage::libsignal_service::profile_name::ProfileName;
use presage::libsignal_service::protocol::ServiceId;
use presage::store::{ContentsStore, Thread};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::convert;
use crate::events::message_json;
use crate::files;
use crate::receiver::ATTACHMENT_PREVIEW;
use crate::threads::{parse_thread_key, thread_key};
use crate::titles::{self, SignalManager};
use crate::worker::{threads_event, Shared};

/// Messages handed to the app when a conversation is opened.
const HISTORY_LIMIT: usize = 300;

#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "camelCase")]
pub enum Command {
    Register {
        phone: String,
        captcha: String,
        #[serde(default)]
        voice: bool,
    },
    Confirm {
        code: String,
    },
    SetProfile {
        name: String,
    },
    Threads,
    History {
        thread: String,
    },
    Send {
        thread: String,
        text: String,
        #[serde(default)]
        attachments: Vec<String>,
        /// The attachment is a recorded voice message.
        #[serde(default)]
        voice: bool,
    },
    Resolve {
        phone: String,
        /// Name from the address book, if the number was picked there.
        #[serde(default)]
        name: String,
    },
    MarkRead {
        thread: String,
    },
    /// `everyone`: also ask the other side(s) to delete it (own messages only).
    DeleteMessage {
        thread: String,
        ts: u64,
        #[serde(default)]
        everyone: bool,
    },
    Reconnect,
}

pub async fn run(manager: &mut SignalManager, shared: &Shared, command: Command) {
    match command {
        Command::SetProfile { name } => set_profile(manager, shared, name).await,
        Command::History { thread } => history(manager, shared, &thread).await,
        Command::Send { thread, text, attachments, voice } => {
            send(manager, shared, &thread, text, &attachments, voice).await
        }
        Command::Resolve { phone, name } => resolve(manager, shared, &phone, &name).await,
        Command::DeleteMessage { thread, ts, everyone } => {
            delete_message(manager, shared, &thread, ts, everyone).await
        }
        // Handled by the worker before getting here.
        Command::Register { .. }
        | Command::Confirm { .. }
        | Command::Threads
        | Command::MarkRead { .. }
        | Command::Reconnect => {}
    }
}

async fn set_profile(manager: &mut SignalManager, shared: &Shared, name: String) {
    let name = ProfileName { given_name: name.trim().to_owned(), family_name: None };
    match manager.update_profile(name, None, None).await {
        Ok(()) => shared.sink.emit(json!({ "ev": "profileSet" })),
        Err(error) => shared.sink.error("setProfile", error),
    }
}

async fn history(manager: &mut SignalManager, shared: &Shared, key: &str) {
    let Some(thread) = parse_thread_key(key) else {
        return shared.sink.error("history", "invalid conversation");
    };
    let own: ServiceId = manager.registration_data().service_ids.aci().into();
    let contents: Vec<_> = match manager.store().messages(&thread, ..).await {
        Ok(iter) => iter.filter_map(Result::ok).collect(),
        Err(error) => return shared.sink.error("history", error),
    };
    let views: Vec<_> = contents.iter().filter_map(|c| convert::view(c, &own)).collect();
    let skip = views.len().saturating_sub(HISTORY_LIMIT);
    let mut names: HashMap<String, String> = HashMap::new();
    let mut rows = Vec::new();
    for view in views.iter().skip(skip) {
        let sender_name = if view.outgoing || matches!(thread, Thread::Contact(_)) {
            String::new()
        } else {
            let id = view.sender.service_id_string();
            match names.get(&id) {
                Some(name) => name.clone(),
                None => {
                    let name = titles::contact_name(manager, &view.sender).await;
                    names.insert(id, name.clone());
                    name
                }
            }
        };
        let stored = files::existing(&shared.attachments_dir, view);
        rows.push(message_json(view, key, &sender_name, &stored));
    }
    shared.sink.emit(json!({ "ev": "history", "thread": key, "messages": rows }));
}

fn now_millis() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
}

async fn send(
    manager: &mut SignalManager,
    shared: &Shared,
    key: &str,
    text: String,
    paths: &[String],
    voice: bool,
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
    let message = DataMessage {
        body: (!text.is_empty()).then(|| text.clone()),
        attachments: pointers,
        timestamp: Some(ts),
        ..Default::default()
    };
    let result = match &thread {
        Thread::Contact(id) => manager.send_message(*id, message, ts).await,
        Thread::Group(master_key) => manager.send_message_to_group(master_key, message, ts).await,
    };
    if let Err(error) = result {
        return fail(error.to_string());
    }
    let stored = files::keep_sent(&shared.attachments_dir, ts, &copies);
    let preview = if text.is_empty() { ATTACHMENT_PREVIEW } else { &text };
    shared.index.borrow_mut().record(key, "", preview, ts, false);
    shared.sink.emit(sent_event(key, &text, ts, &stored));
    shared.sink.emit(threads_event(shared));
}

fn sent_event(key: &str, text: &str, ts: u64, stored: &[crate::events::StoredFile]) -> Value {
    let attachments: Vec<Value> =
        stored.iter().map(|f| json!({ "path": f.path, "type": f.content_type })).collect();
    json!({ "ev": "sent", "thread": key, "outgoing": true, "sender": "", "senderName": "",
            "text": text, "ts": ts, "attachments": attachments })
}

/// Parses a number as typed or stored in the address book. Numbers without
/// a country code ("0170 1234567") count as numbers of our own country.
fn parse_number(manager: &SignalManager, phone: &str) -> Result<PhoneNumber, String> {
    let home = manager.registration_data().phone_number.country().id();
    phonenumber::parse(home, phone.trim()).map_err(|e| e.to_string())
}

async fn resolve(manager: &mut SignalManager, shared: &Shared, phone: &str, name: &str) {
    let number = match parse_number(manager, phone) {
        Ok(number) => number,
        Err(error) => return shared.sink.error_kind("resolve", "phoneNumber", error),
    };
    let found = match manager.discover_contacts_by_phone_number(vec![number.clone()]).await {
        Ok(found) => found.into_iter().find_map(|(_, id)| id),
        Err(error) => return shared.sink.error("resolve", error),
    };
    let Some(id) = found else {
        return shared.sink.error_kind("resolve", "noAccount", number);
    };
    let key = thread_key(&Thread::Contact(id));
    // The address book name is what the user knows the person by; then the
    // name from their Signal profile, then the number.
    let mut title = name.trim().to_owned();
    if title.is_empty() {
        title = titles::contact_name(manager, &id).await;
    }
    if title.is_empty() {
        title = number.to_string();
    }
    shared.index.borrow_mut().ensure(&key, &title);
    shared.sink.emit(json!({ "ev": "resolved", "thread": key, "title": title }));
    shared.sink.emit(threads_event(shared));
}

/// Deletes a message from this phone; with `everyone`, first sends Signal's
/// delete request to the conversation, which also blanks the stored copy.
async fn delete_message(
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
        let result = match &thread {
            Thread::Contact(id) => manager.send_message(*id, request, now).await,
            Thread::Group(master_key) => {
                manager.send_message_to_group(master_key, request, now).await
            }
        };
        if let Err(error) = result {
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
