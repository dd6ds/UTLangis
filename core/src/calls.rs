//! One-to-one Signal calls as the chats show them: an incoming call rings
//! ("incomingCall" event) until it is answered here or on another of our
//! devices, declined, given up by the caller, or nobody answers; every call
//! ends up as a row of its chat ("call" event and history). presage does not
//! store call messages, so the calls are kept in a small JSON file next to
//! the database. The call itself runs in libutlangis_calls (see
//! callsignal.rs for the signalling).

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::time::Duration;

use presage::libsignal_service::content::Content;
use presage::libsignal_service::protocol::ServiceId;
use presage::proto::call_message::{
    hangup::Type as HangupType, offer::Type as OfferType, Hangup, Offer,
};
use presage::proto::CallMessage;
use presage::store::Thread;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::callsignal;
use crate::commands::now_millis;
use crate::threads::thread_key;
use crate::titles::{self, SignalManager};
use crate::worker::{threads_event, Shared};

/// Nobody answered: the caller gave up or the call rang out.
pub const MISSED: &str = "missed";
/// Declined on this phone.
pub const DECLINED: &str = "declined";
/// Answered on another of our devices (e.g. Signal Desktop).
pub const ANSWERED_ELSEWHERE: &str = "answeredElsewhere";
/// Declined on another of our devices.
pub const DECLINED_ELSEWHERE: &str = "declinedElsewhere";
/// Answered on this phone.
pub const ANSWERED: &str = "answered";
/// A call we made.
pub const OUTGOING: &str = "outgoing";

/// Signal's apps stop ringing after a minute; older offers (e.g. received
/// after the app was suspended) are recorded as missed right away.
const RING_TIME: Duration = Duration::from_secs(60);

/// Shown in the conversation list for a call.
pub const CALL_PREVIEW: &str = "📞";

/// Oldest calls are dropped beyond this.
const MAX_ENTRIES: usize = 5_000;

#[derive(Clone, Serialize, Deserialize)]
pub struct CallEntry {
    pub thread: String,
    /// When the call started (the offer's sent time), ms since the epoch.
    pub ts: u64,
    pub video: bool,
    pub outcome: String,
}

/// A call that is ringing right now.
pub struct Ringing {
    thread: String,
    title: String,
    ts: u64,
    video: bool,
    caller: ServiceId,
    /// The caller's device, which the answer to the offer goes to.
    device: u32,
}

pub struct Calls {
    path: PathBuf,
    log: Vec<CallEntry>,
    ringing: HashMap<u64, Ringing>,
}

impl Calls {
    pub fn load(data_dir: &Path) -> Self {
        let path = data_dir.join("calls.json");
        let log = std::fs::read(&path)
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default();
        Calls { path, log, ringing: HashMap::new() }
    }

    fn add(&mut self, entry: CallEntry) {
        self.log.push(entry);
        if self.log.len() > MAX_ENTRIES {
            let excess = self.log.len() - MAX_ENTRIES;
            self.log.drain(..excess);
        }
        self.save();
    }

    fn save(&self) {
        match serde_json::to_vec(&self.log) {
            Ok(bytes) => {
                if let Err(error) = std::fs::write(&self.path, bytes) {
                    tracing::warn!(%error, "could not save calls");
                }
            }
            Err(error) => tracing::warn!(%error, "could not encode calls"),
        }
    }

    /// The calls of one chat as message rows, for its history.
    pub fn rows(&self, thread: &str) -> Vec<Value> {
        self.log.iter().filter(|entry| entry.thread == thread).map(row).collect()
    }

    /// A chat was merged into another (phone number identity → account).
    pub fn rename_thread(&mut self, from: &str, to: &str) {
        let mut changed = false;
        for entry in self.log.iter_mut().filter(|entry| entry.thread == from) {
            entry.thread = to.to_owned();
            changed = true;
        }
        if changed {
            self.save();
        }
    }
}

/// A call as a row of the chat: no text, `call` tells how it ended.
pub fn row(entry: &CallEntry) -> Value {
    json!({ "thread": entry.thread, "ts": entry.ts, "outgoing": false, "text": "",
            "sender": "", "senderName": "", "attachments": [],
            "call": entry.outcome, "video": entry.video })
}

/// Call signalling from someone calling us: goes on to the app for RingRTC;
/// offers (a call starts) and hang-ups (it ends) also make the call log.
pub async fn on_call_message(
    manager: &mut SignalManager,
    shared: &Rc<Shared>,
    content: &Content,
    call: &CallMessage,
) {
    callsignal::forward(manager, shared, content, call).await;
    if let Some(Offer { id: Some(id), r#type, .. }) = &call.offer {
        let video = *r#type == Some(OfferType::OfferVideoCall as i32);
        return on_offer(manager, shared, content, *id, video).await;
    }
    if let Some(Hangup { id: Some(id), r#type, .. }) = &call.hangup {
        let outcome = match r#type.and_then(|kind| HangupType::try_from(kind).ok()) {
            Some(HangupType::HangupAccepted) => ANSWERED_ELSEWHERE,
            Some(HangupType::HangupDeclined) => DECLINED_ELSEWHERE,
            _ => MISSED,
        };
        end(shared, *id, outcome);
    }
}

/// A call starts ringing here (or is recorded as missed if the offer is old).
async fn on_offer(
    manager: &mut SignalManager,
    shared: &Rc<Shared>,
    content: &Content,
    id: u64,
    video: bool,
) {
    let caller = content.metadata.sender;
    let thread = Thread::Contact(caller);
    let key = thread_key(&thread);
    let title = titles::thread_title(manager, &thread).await;
    let ts = content.metadata.client_timestamp.timestamp_millis().max(0) as u64;
    let sent = content.metadata.server_timestamp.timestamp_millis().max(0) as u64;
    if now_millis().saturating_sub(sent) > RING_TIME.as_millis() as u64 {
        return record(shared, &key, &title, ts, video, MISSED, None);
    }
    let device = u32::from(content.metadata.sender_device);
    let ringing = Ringing { thread: key.clone(), title: title.clone(), ts, video, caller, device };
    shared.calls.borrow_mut().ringing.insert(id, ringing);
    shared.sink.emit(json!({ "ev": "incomingCall", "thread": key, "title": title,
                             // Random 64-bit ids do not fit a JavaScript number.
                             "callId": id.to_string(), "video": video }));
    let shared = Rc::clone(shared);
    tokio::task::spawn_local(async move {
        tokio::time::sleep(RING_TIME).await;
        end(&shared, id, MISSED);
    });
}

/// The ringing call `id` is over; returns it if it was still ringing.
fn end(shared: &Shared, id: u64, outcome: &str) -> Option<Ringing> {
    let ringing = shared.calls.borrow_mut().ringing.remove(&id)?;
    record(shared, &ringing.thread, &ringing.title, ringing.ts, ringing.video, outcome, Some(id));
    Some(ringing)
}

fn record(
    shared: &Shared,
    key: &str,
    title: &str,
    ts: u64,
    video: bool,
    outcome: &str,
    id: Option<u64>,
) {
    let entry = CallEntry { thread: key.to_owned(), ts, video, outcome: outcome.to_owned() };
    shared.calls.borrow_mut().add(entry.clone());
    shared.index.borrow_mut().record(key, title, CALL_PREVIEW, ts, outcome == MISSED);
    let mut event = row(&entry);
    event["ev"] = "call".into();
    event["title"] = title.into();
    if let Some(id) = id {
        event["callId"] = id.to_string().into();
    }
    shared.sink.emit(event);
    shared.sink.emit(threads_event(shared));
}

/// Declines the ringing call `call_id` (as sent in "incomingCall"): the
/// caller's app shows it as declined.
pub async fn decline(manager: &mut SignalManager, shared: &Shared, call_id: &str) {
    let Ok(id) = call_id.parse::<u64>() else {
        return;
    };
    let Some(ringing) = end(shared, id, DECLINED) else {
        return;
    };
    let hangup = CallMessage {
        hangup: Some(Hangup {
            id: Some(id),
            r#type: Some(HangupType::HangupNormal as i32),
            device_id: Some(u32::from(manager.device_id())),
        }),
        destination_device_id: Some(ringing.device),
        ..Default::default()
    };
    if let Err(error) = manager.send_message(ringing.caller, hangup, now_millis()).await {
        shared.sink.error("declineCall", error);
    }
}

/// The ringing call `call_id` was answered on this phone.
pub fn answered(shared: &Shared, call_id: &str) {
    if let Ok(id) = call_id.parse::<u64>() {
        end(shared, id, ANSWERED);
    }
}

/// We called someone: a row in their chat.
pub async fn started(manager: &mut SignalManager, shared: &Shared, key: &str, video: bool) {
    let Some(thread) = crate::threads::parse_thread_key(key) else {
        return;
    };
    let title = titles::thread_title(manager, &thread).await;
    record(shared, key, &title, now_millis(), video, OUTGOING, None);
}
