//! Commands from the app, and the ones that need a registered account.

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use presage::libsignal_service::content::DataMessage;
use presage::proto::data_message::{quote, Delete, Quote, Reaction};
use presage::proto::receipt_message::Type as ReceiptType;
use presage::proto::ReceiptMessage;
use presage::libsignal_service::prelude::phonenumber::{self, PhoneNumber};
use presage::libsignal_service::profile_name::ProfileName;
use presage::libsignal_service::protocol::ServiceId;
use presage::store::{ContentsStore, Thread};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::convert;
use crate::receipts;
use crate::events::{add_quote, files_json, message_json, StoredFile};
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
    /// Link as an additional device of an existing account (QR code).
    Link {
        #[serde(default = "default_device_name", rename = "deviceName")]
        device_name: String,
    },
    CancelLink,
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
        /// The message this one replies to.
        #[serde(default)]
        quote: Option<QuoteRequest>,
    },
    Resolve {
        phone: String,
        /// Name from the address book, if the number was picked there.
        #[serde(default)]
        name: String,
    },
    /// React to a message with an emoji, or take the reaction back.
    React {
        thread: String,
        /// Sent timestamp of the message.
        ts: u64,
        /// Its author's service id; "" for one of our own messages.
        #[serde(default)]
        author: String,
        emoji: String,
        #[serde(default)]
        remove: bool,
    },
    /// The user's own name for a one-to-one chat; "" goes back to the
    /// person's Signal profile name.
    RenameThread {
        thread: String,
        name: String,
    },
    MarkRead {
        thread: String,
        /// Send read receipts for the messages now seen (user setting).
        #[serde(default, rename = "readReceipts")]
        read_receipts: bool,
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

fn default_device_name() -> String {
    "UT Langis (Ubuntu Touch)".to_owned()
}

/// A reply's reference to an earlier message of the conversation.
#[derive(Deserialize)]
pub struct QuoteRequest {
    /// Sent timestamp of the quoted message (its id).
    ts: u64,
    /// Service id of its author; "" for one of our own messages.
    #[serde(default)]
    author: String,
    #[serde(default)]
    text: String,
    /// Author's name as the app shows it, echoed in the "sent" event.
    #[serde(default)]
    name: String,
}

pub async fn run(manager: &mut SignalManager, shared: &Shared, command: Command) {
    match command {
        Command::SetProfile { name } => set_profile(manager, shared, name).await,
        Command::History { thread } => history(manager, shared, &thread).await,
        Command::Send { thread, text, attachments, voice, quote } => {
            send(manager, shared, &thread, text, &attachments, voice, quote).await
        }
        Command::Resolve { phone, name } => resolve(manager, shared, &phone, &name).await,
        Command::React { thread, ts, author, emoji, remove } => {
            react(manager, shared, &thread, ts, &author, &emoji, remove).await
        }
        Command::RenameThread { thread, name } => {
            rename_thread(manager, shared, &thread, &name).await
        }
        Command::DeleteMessage { thread, ts, everyone } => {
            delete_message(manager, shared, &thread, ts, everyone).await
        }
        // Handled by the worker before getting here.
        Command::Register { .. }
        | Command::Confirm { .. }
        | Command::Link { .. }
        | Command::CancelLink
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
    // Reactions are stored as messages of their own, in order: the latest
    // one of each reactor counts, a removal takes it back.
    let mut reactions: HashMap<u64, serde_json::Map<String, Value>> = HashMap::new();
    for reaction in contents.iter().filter_map(|c| convert::reaction(c, &own)) {
        let entry = reactions.entry(reaction.target).or_default();
        if reaction.remove {
            entry.remove(&reaction.reactor);
        } else {
            entry.insert(reaction.reactor, reaction.emoji.into());
        }
    }
    let skip = views.len().saturating_sub(HISTORY_LIMIT);
    let mut names: HashMap<String, String> = HashMap::new();
    let mut rows = Vec::new();
    for view in views.iter().skip(skip) {
        let sender_name = if view.outgoing || matches!(thread, Thread::Contact(_)) {
            String::new()
        } else {
            titles::cached_name(manager, &view.sender, &mut names).await
        };
        let quote_name = match view.quote.as_ref().and_then(|q| q.author.filter(|_| !q.own)) {
            Some(author) => titles::cached_name(manager, &author, &mut names).await,
            None => String::new(),
        };
        let stored = files::existing(&shared.attachments_dir, view);
        let mut row = message_json(view, key, &sender_name, &quote_name, &stored);
        if view.outgoing {
            row["status"] = shared.receipts.borrow().status(view.ts).into();
        }
        if let Some(found) = reactions.remove(&view.ts) {
            row["reactions"] = Value::Object(found);
        }
        rows.push(row);
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
    // Without the person's profile key Signal only reveals their phone number
    // identity (PNI); once a reply showed their account id, the chat
    // continues there (see merge_pni_thread).
    let key = shared.index.borrow().current_key(&thread_key(&Thread::Contact(id)));
    // The address book name is what the user knows the person by; then the
    // name from their Signal profile, then the number.
    let custom = !name.trim().is_empty();
    let mut title = name.trim().to_owned();
    if title.is_empty() {
        title = titles::contact_name(manager, &id).await;
    }
    if title.is_empty() {
        title = number.to_string();
    }
    shared.index.borrow_mut().ensure(&key, &title, custom);
    let title = shared.index.borrow().title(&key).unwrap_or(&title).to_owned();
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

/// Tells the senders of `messages` (sender, sent timestamp) that they
/// reached this phone (`Delivery`) or were seen (`Read`), one receipt per
/// sender as Signal's apps do. Failures only cost the sender a tick.
pub async fn send_receipts(
    manager: &mut SignalManager,
    messages: Vec<(ServiceId, u64)>,
    kind: ReceiptType,
) {
    let mut by_sender: HashMap<ServiceId, Vec<u64>> = HashMap::new();
    for (sender, ts) in messages {
        by_sender.entry(sender).or_default().push(ts);
    }
    for (sender, timestamps) in by_sender {
        let receipt = ReceiptMessage { r#type: Some(kind as i32), timestamp: timestamps };
        if let Err(error) = manager.send_message(sender, receipt, now_millis()).await {
            tracing::info!(%error, "receipt not sent");
        }
    }
}

async fn rename_thread(manager: &mut SignalManager, shared: &Shared, key: &str, name: &str) {
    let Some(thread) = parse_thread_key(key) else {
        return shared.sink.error("renameThread", "invalid conversation");
    };
    let fallback = if name.trim().is_empty() {
        titles::thread_title(manager, &thread).await
    } else {
        String::new()
    };
    shared.index.borrow_mut().rename(key, name.trim(), &fallback);
    shared.sink.emit(threads_event(shared));
}

/// Someone replied from their account id (ACI) and proved that the phone
/// number identity (PNI) we wrote to is theirs. Moves the messages of the
/// PNI chat into the ACI chat so the conversation is one chat again, and
/// tells the app (event "merged") to switch if that chat is open.
pub async fn merge_pni_thread(
    manager: &mut SignalManager,
    shared: &Shared,
    pni: ServiceId,
    aci: ServiceId,
) {
    let from = Thread::Contact(pni);
    let to = Thread::Contact(aci);
    let (from_key, to_key) = (thread_key(&from), thread_key(&to));
    let mut store = manager.store().clone();
    let contents: Vec<_> = match store.messages(&from, ..).await {
        Ok(iter) => iter.filter_map(Result::ok).collect(),
        Err(error) => return tracing::warn!(%error, "could not read the chat to merge"),
    };
    for content in contents {
        if let Err(error) = store.save_message(&to, content).await {
            return tracing::warn!(%error, "could not merge the chat");
        }
    }
    if let Err(error) = store.clear_thread(&from).await {
        tracing::warn!(%error, "could not clear the merged chat");
    }
    shared.index.borrow_mut().merge(&from_key, &to_key);
    shared.sink.emit(json!({ "ev": "merged", "from": from_key, "to": to_key }));
    shared.sink.emit(threads_event(shared));
}

async fn react(
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
    let result = match &thread {
        Thread::Contact(id) => manager.send_message(*id, message, now).await,
        Thread::Group(master_key) => manager.send_message_to_group(master_key, message, now).await,
    };
    if let Err(error) = result {
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
