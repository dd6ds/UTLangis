//! C interface of the ubSignal backend (see include/ubsignal_core.h).
//!
//! Commands (JSON objects with a "cmd" field):
//! - `register` {phone, captcha, voice}: request a verification code
//! - `confirm` {code}: finish the registration as primary device
//! - `setProfile` {name}: set the profile name others see
//! - `threads`: list the conversations
//! - `history` {thread}: the stored messages of one conversation
//! - `send` {thread, text, attachments: [paths]}
//! - `resolve` {phone}: find the Signal account of a phone number
//! - `markRead` {thread}
//! - `reconnect`: reopen the message connection (after the app was suspended)
//!
//! Events (JSON objects with an "ev" field): `state`, `error`, `threads`,
//! `history`, `message`, `sent`, `resolved`. Their fields are built in
//! worker.rs and events.rs.

mod commands;
mod convert;
mod events;
mod files;
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
/// callable with `context` until `ubsignal_stop` has returned.
#[no_mangle]
pub unsafe extern "C" fn ubsignal_start(
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
        .name("ubsignal-core".into())
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
pub unsafe extern "C" fn ubsignal_command(json: *const c_char) {
    if json.is_null() {
        return;
    }
    let command = CStr::from_ptr(json).to_string_lossy().into_owned();
    if let Some(backend) = BACKEND.lock().unwrap_or_else(|e| e.into_inner()).as_ref() {
        let _ = backend.commands.send(command);
    }
}

#[no_mangle]
pub extern "C" fn ubsignal_stop() {
    let backend = BACKEND.lock().unwrap_or_else(|e| e.into_inner()).take();
    if let Some(Backend { commands, thread }) = backend {
        // Closing the channel ends the worker's command loop.
        drop(commands);
        let _ = thread.join();
    }
}
