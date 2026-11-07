//! Commands from the app, and the ones that need a registered account.

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use presage::proto::receipt_message::Type as ReceiptType;
use presage::proto::ReceiptMessage;
use presage::libsignal_service::prelude::phonenumber::{self, PhoneNumber};
use presage::libsignal_service::profile_name::ProfileName;
use presage::libsignal_service::protocol::ServiceId;
use presage::store::Thread;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::calls;
use crate::callsignal;
use crate::devices;
use crate::history;
use crate::merge;
use crate::messaging;
use crate::outgoing;
use crate::threads::{parse_thread_key, thread_key};
use crate::titles::{self, SignalManager};
use crate::worker::{threads_event, Shared};

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
    /// Look for a Signal linking QR code in a camera photo (then removed).
    ScanQr {
        path: String,
    },
    /// Link another device (Signal Desktop) by its QR code's address.
    LinkDevice {
        url: String,
    },
    /// The devices of our account.
    Devices,
    /// Join a chat started with a phone number identity (`from`, "c:PNI:…")
    /// into the person's chat (`to`), when the user knows they are the same.
    MergeChats {
        from: String,
        to: String,
    },
    /// Send a call signalling message from libutlangis_calls.
    SendCallSignal {
        signal: Value,
    },
    /// Fetch TURN servers for a call ("turnServers" event).
    TurnServers,
    /// The ringing call was answered here.
    CallAnswered {
        #[serde(rename = "callId")]
        call_id: String,
    },
    /// We started a call in `thread`.
    CallStarted {
        thread: String,
        #[serde(default)]
        video: bool,
    },
    /// Decline a ringing call (id as in "incomingCall").
    DeclineCall {
        #[serde(rename = "callId")]
        call_id: String,
    },
    UnlinkDevice {
        id: u32,
    },
    /// Change the text of one of our sent messages.
    EditMessage {
        thread: String,
        /// Sent timestamp of the message.
        ts: u64,
        text: String,
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
    pub ts: u64,
    /// Service id of its author; "" for one of our own messages.
    #[serde(default)]
    pub author: String,
    #[serde(default)]
    pub text: String,
    /// Author's name as the app shows it, echoed in the "sent" event.
    #[serde(default)]
    pub name: String,
}

pub async fn run(manager: &mut SignalManager, shared: &Shared, command: Command) {
    match command {
        Command::SetProfile { name } => set_profile(manager, shared, name).await,
        Command::History { thread } => history::history(manager, shared, &thread).await,
        Command::Send { thread, text, attachments, voice, quote } => {
            messaging::send(manager, shared, &thread, text, &attachments, voice, quote).await
        }
        Command::Resolve { phone, name } => resolve(manager, shared, &phone, &name).await,
        Command::React { thread, ts, author, emoji, remove } => {
            messaging::react(manager, shared, &thread, ts, &author, &emoji, remove).await
        }
        Command::RenameThread { thread, name } => {
            rename_thread(manager, shared, &thread, &name).await
        }
        Command::ScanQr { path } => devices::scan(shared, &path).await,
        Command::LinkDevice { url } => devices::link(manager, shared, &url).await,
        Command::Devices => devices::list(manager, shared).await,
        Command::DeclineCall { call_id } => calls::decline(manager, shared, &call_id).await,
        Command::SendCallSignal { signal } => callsignal::send(manager, shared, &signal).await,
        Command::TurnServers => callsignal::turn_servers(manager, shared).await,
        Command::CallAnswered { call_id } => calls::answered(shared, &call_id),
        Command::CallStarted { thread, video } => {
            calls::started(manager, shared, &thread, video).await
        }
        Command::MergeChats { from, to } => merge::merge_chats(manager, shared, &from, &to).await,
        Command::UnlinkDevice { id } => devices::unlink(manager, shared, id).await,
        Command::EditMessage { thread, ts, text } => {
            outgoing::edit_message(manager, shared, &thread, ts, &text).await
        }
        Command::DeleteMessage { thread, ts, everyone } => {
            messaging::delete_message(manager, shared, &thread, ts, everyone).await
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

pub fn now_millis() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0)
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
    // continues there (see merge.rs).
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
