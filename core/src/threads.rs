//! Conversation list. presage stores messages per thread but has no list of
//! threads with their latest message, so the list is kept here as a small
//! JSON file next to the database.

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use presage::libsignal_service::protocol::ServiceId;
use presage::store::Thread;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

/// Text form of a thread used by the app: "c:<service id>" for a contact,
/// "g:<master key hex>" for a group.
pub fn thread_key(thread: &Thread) -> String {
    match thread {
        Thread::Contact(id) => format!("c:{}", id.service_id_string()),
        Thread::Group(key) => format!("g:{}", hex::encode(key)),
    }
}

pub fn parse_thread_key(key: &str) -> Option<Thread> {
    if let Some(id) = key.strip_prefix("c:") {
        return ServiceId::parse_from_service_id_string(id).map(Thread::Contact);
    }
    let bytes = hex::decode(key.strip_prefix("g:")?).ok()?;
    Some(Thread::Group(bytes.try_into().ok()?))
}

#[derive(Serialize, Deserialize, Clone, Default)]
struct ThreadInfo {
    title: String,
    last_text: String,
    last_ts: u64,
    unread: u32,
}

pub struct ThreadIndex {
    path: PathBuf,
    threads: HashMap<String, ThreadInfo>,
}

impl ThreadIndex {
    pub fn load(data_dir: &Path) -> Self {
        let path = data_dir.join("threads.json");
        let threads = std::fs::read(&path)
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default();
        ThreadIndex { path, threads }
    }

    fn save(&self) {
        match serde_json::to_vec(&self.threads) {
            Ok(bytes) => {
                if let Err(error) = std::fs::write(&self.path, bytes) {
                    tracing::warn!(%error, "could not save the thread list");
                }
            }
            Err(error) => tracing::warn!(%error, "could not encode the thread list"),
        }
    }

    pub fn title(&self, key: &str) -> Option<&str> {
        self.threads.get(key).map(|t| t.title.as_str()).filter(|t| !t.is_empty())
    }

    /// Adds a conversation that has no messages yet (a new chat).
    pub fn ensure(&mut self, key: &str, title: &str) {
        let entry = self.threads.entry(key.to_owned()).or_default();
        if entry.title.is_empty() {
            entry.title = title.to_owned();
        }
        self.save();
    }

    /// Notes a new message. Incoming messages count as unread unless the
    /// conversation is open (`reading`).
    pub fn record(&mut self, key: &str, title: &str, text: &str, ts: u64, unread: bool) {
        let entry = self.threads.entry(key.to_owned()).or_default();
        if !title.is_empty() {
            entry.title = title.to_owned();
        }
        if ts >= entry.last_ts {
            entry.last_ts = ts;
            entry.last_text = text.to_owned();
        }
        if unread {
            entry.unread += 1;
        }
        self.save();
    }

    /// Clears the preview if it shows the deleted message with timestamp `ts`.
    pub fn forget_preview(&mut self, key: &str, ts: u64) {
        if let Some(entry) = self.threads.get_mut(key) {
            if entry.last_ts == ts && !entry.last_text.is_empty() {
                entry.last_text.clear();
                self.save();
            }
        }
    }

    pub fn mark_read(&mut self, key: &str) {
        if let Some(entry) = self.threads.get_mut(key) {
            if entry.unread > 0 {
                entry.unread = 0;
                self.save();
            }
        }
    }

    /// All conversations, newest first.
    pub fn to_json(&self) -> Value {
        let mut list: Vec<_> = self.threads.iter().collect();
        list.sort_by(|a, b| b.1.last_ts.cmp(&a.1.last_ts));
        Value::Array(
            list.into_iter()
                .map(|(key, t)| {
                    json!({ "thread": key, "title": t.title, "lastText": t.last_text,
                            "lastTs": t.last_ts, "unread": t.unread })
                })
                .collect(),
        )
    }
}
