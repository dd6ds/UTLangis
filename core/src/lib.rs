//! C interface of the UT Langis backend (see include/utlangis_core.h).
//!
//! Commands (JSON objects with a "cmd" field):
//! - `register` {phone, captcha, voice}: request a verification code
//! - `confirm` {code}: finish the registration as primary device
//! - `link` {deviceName}: link as an additional device instead (QR code)
//! - `cancelLink`
//! - `setProfile` {name}: set the profile name others see
//! - `threads`: list the conversations
//! - `history` {thread}: the stored messages of one conversation
//! - `send` {thread, text, attachments: [paths], voice, quote: {ts, author, text,
//!   name}}: `quote` makes it a reply
//! - `resolve` {phone}: find the Signal account of a phone number
//! - `react` {thread, ts, author, emoji, remove}: react to a message
//! - `renameThread` {thread, name}: own name for a chat ("" = profile name)
//! - `markRead` {thread, readReceipts}: also tells the senders (if allowed)
//! - `editMessage` {thread, ts, text}: change the text of a sent message
//! - `deleteMessage` {thread, ts, everyone}: delete for this phone, or for all
//! - `scanQr` {path}: look for a linking QR code in a camera photo
//! - `linkDevice` {url}, `devices`, `unlinkDevice` {id}: other devices of the
//!   account (primary device only)
//! - `declineCall` {callId}: decline a ringing call
//! - `sendCallSignal` {signal}, `turnServers`, `callAnswered` {callId},
//!   `callStarted` {thread, video}: calls run by libutlangis_calls
//! - `mergeChats` {from, to}: join a phone number chat into the person's chat
//! - `reconnect`: reopen the message connection (after the app was suspended)
//!
//! Events (JSON objects with an "ev" field): `state`, `error`, `threads`,
//! `history`, `message`, `sent`, `resolved`, `deleted` {thread, ts},
//! `receipt` {ts: [..], status}, `merged` {from, to},
//! `reaction` {thread, target, reactor, emoji, remove}, `linkQr` {path},
//! `account` {linked}, `edited` {thread, target, text}, `qrScanned` {text},
//! `qrNone`, `deviceLinked`, `devices` {devices},
//! `incomingCall` {thread, title, callId, video}, `callSignal` (a received
//! call signalling message for RingRTC), `turnServers` {servers},
//! `call` (a call row with
//! `call` = how it ended, `title`, `callId` if it rang here). Their fields are built in
//! worker.rs, events.rs and devices.rs.

mod calls;
mod callsignal;
mod commands;
mod convert;
mod devices;
mod events;
mod files;
mod history;
mod linking;
mod merge;
mod messaging;
mod outgoing;
mod qr;
mod receipts;
mod receiver;
mod threads;
mod titles;
mod worker;

use std::ffi::{c_char, c_void, CStr};
use std::path::PathBuf;
use std::sync::Mutex;
use std::thread::JoinHandle;

use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};

use crate::events::{EventCallback, EventSink};

struct Backend {
    commands: UnboundedSender<String>,
    thread: JoinHandle<()>,
}

static BACKEND: Mutex<Option<Backend>> = Mutex::new(None);

/// # Safety
/// `data_dir` must be a valid NUL-terminated string. `callback` must stay
/// callable with `context` until `utlangis_stop` has returned.
#[no_mangle]
pub unsafe extern "C" fn utlangis_start(
    data_dir: *const c_char,
    callback: EventCallback,
    context: *mut c_void,
) -> bool {
    if data_dir.is_null() {
        return false;
    }
    let data_dir = PathBuf::from(CStr::from_ptr(data_dir).to_string_lossy().into_owned());
    if std::fs::create_dir_all(&data_dir).is_err() {
        return false;
    }
    let mut backend = BACKEND.lock().unwrap_or_else(|e| e.into_inner());
    if backend.is_some() {
        return false;
    }
    let sink = EventSink::new(callback, context);
    let (commands, receiver) = unbounded_channel();
    let thread = std::thread::Builder::new()
        .name("utlangis-core".into())
        .spawn(move || worker::run(data_dir, sink, receiver));
    match thread {
        Ok(thread) => {
            *backend = Some(Backend { commands, thread });
            true
        }
        Err(_) => false,
    }
}

/// # Safety
/// `json` must be a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn utlangis_command(json: *const c_char) {
    if json.is_null() {
        return;
    }
    let command = CStr::from_ptr(json).to_string_lossy().into_owned();
    if let Some(backend) = BACKEND.lock().unwrap_or_else(|e| e.into_inner()).as_ref() {
        let _ = backend.commands.send(command);
    }
}

#[no_mangle]
pub extern "C" fn utlangis_stop() {
    let backend = BACKEND.lock().unwrap_or_else(|e| e.into_inner()).take();
    if let Some(Backend { commands, thread }) = backend {
        // Closing the channel ends the worker's command loop.
        drop(commands);
        let _ = thread.join();
    }
}
