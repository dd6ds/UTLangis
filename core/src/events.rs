//! Events sent to the Qt side as JSON through the C callback.

use std::ffi::{c_char, c_void, CString};

use serde_json::{json, Value};

use crate::convert::MessageView;

pub type EventCallback = extern "C" fn(context: *mut c_void, json: *const c_char);

/// Registration and connection state shown by the app.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum State {
    /// No account yet: the registration page is shown.
    Unregistered,
    /// A verification code was requested and is awaited.
    AwaitingCode,
    /// Linking as an additional device: the QR code is shown.
    Linking,
    /// Registered, but the message connection is not open.
    Offline,
    /// Registered and receiving messages.
    Online,
}

impl State {
    fn name(self) -> &'static str {
        match self {
            State::Unregistered => "unregistered",
            State::AwaitingCode => "awaitingCode",
            State::Linking => "linking",
            State::Offline => "offline",
            State::Online => "online",
        }
    }
}

pub struct EventSink {
    callback: EventCallback,
    // Stored as an address so the sink can move to the backend thread; the
    // C side guarantees the pointer stays valid while the backend runs.
    context: usize,
}

impl EventSink {
    pub fn new(callback: EventCallback, context: *mut c_void) -> Self {
        EventSink { callback, context: context as usize }
    }

    pub fn emit(&self, event: Value) {
        let Ok(text) = CString::new(event.to_string()) else {
            return;
        };
        (self.callback)(self.context as *mut c_void, text.as_ptr());
    }

    pub fn state(&self, state: State, phone: &str) {
        self.emit(json!({ "ev": "state", "state": state.name(), "phone": phone }));
    }

    /// `action` names the command that failed so the app can show the error
    /// where it belongs (e.g. on the registration page). `kind` is a short
    /// code the app translates; "other" means only `message` is available.
    pub fn error_kind(&self, action: &str, kind: &str, message: impl std::fmt::Display) {
        tracing::warn!(action, kind, %message, "command failed");
        self.emit(json!({ "ev": "error", "action": action, "kind": kind,
                          "message": message.to_string() }));
    }

    pub fn error(&self, action: &str, message: impl std::fmt::Display) {
        self.error_kind(action, "other", message);
    }
}

/// A downloaded or sent attachment stored on the phone.
pub struct StoredFile {
    pub path: String,
    pub content_type: String,
}

/// One message row as the app shows it ("message" events and "history").
/// `quote_name` is the name of the quoted message's author ("" if unknown or
/// if it is one of our own messages).
pub fn message_json(
    view: &MessageView,
    thread: &str,
    sender_name: &str,
    quote_name: &str,
    files: &[StoredFile],
) -> Value {
    let mut row = json!({
        "thread": thread,
        "sender": view.sender.service_id_string(),
        "senderName": sender_name,
        "outgoing": view.outgoing,
        "text": view.text,
        "ts": view.ts,
        "attachments": files_json(files),
    });
    if let Some(quote) = &view.quote {
        add_quote(&mut row, &quote.text, quote_name, quote.own);
    }
    row
}

pub fn files_json(files: &[StoredFile]) -> Value {
    files.iter().map(|f| json!({ "path": f.path, "type": f.content_type })).collect()
}

/// Adds the quoted message of a reply to a message row.
pub fn add_quote(row: &mut Value, text: &str, author_name: &str, own: bool) {
    row["hasQuote"] = true.into();
    row["quoteText"] = text.into();
    row["quoteAuthor"] = author_name.into();
    row["quoteOwn"] = own.into();
}
