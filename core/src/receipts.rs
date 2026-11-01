//! Delivery state of our own messages: sent, delivered to a device of the
//! recipient, read. presage stores receipts as messages of the sender's
//! one-to-one thread (also for group messages), so the state is kept here,
//! by message timestamp, in a small JSON file next to the database.

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use presage::proto::receipt_message::Type as ReceiptType;

pub const SENT: u8 = 1;
pub const DELIVERED: u8 = 2;
pub const READ: u8 = 3;

/// Oldest entries are dropped beyond this; their messages show no state.
const MAX_ENTRIES: usize = 20_000;

pub fn status_of(kind: Option<i32>) -> u8 {
    match kind.and_then(|k| ReceiptType::try_from(k).ok()) {
        Some(ReceiptType::Read) | Some(ReceiptType::Viewed) => READ,
        _ => DELIVERED,
    }
}

pub struct Receipts {
    path: PathBuf,
    states: HashMap<u64, u8>,
}

impl Receipts {
    pub fn load(data_dir: &Path) -> Self {
        let path = data_dir.join("receipts.json");
        let states = std::fs::read(&path)
            .ok()
            .and_then(|bytes| serde_json::from_slice(&bytes).ok())
            .unwrap_or_default();
        Receipts { path, states }
    }

    fn save(&mut self) {
        if self.states.len() > MAX_ENTRIES {
            let mut keys: Vec<u64> = self.states.keys().copied().collect();
            keys.sort_unstable();
            for key in &keys[..self.states.len() - MAX_ENTRIES] {
                self.states.remove(key);
            }
        }
        match serde_json::to_vec(&self.states) {
            Ok(bytes) => {
                if let Err(error) = std::fs::write(&self.path, bytes) {
                    tracing::warn!(%error, "could not save receipts");
                }
            }
            Err(error) => tracing::warn!(%error, "could not encode receipts"),
        }
    }

    /// 0 if nothing is known about the message.
    pub fn status(&self, ts: u64) -> u8 {
        self.states.get(&ts).copied().unwrap_or(0)
    }

    /// Raises the state of our message `ts`. Receipts for messages we do not
    /// know as sent are ignored. Returns whether anything changed.
    pub fn raise(&mut self, ts: u64, status: u8) -> bool {
        let known = status == SENT || self.states.contains_key(&ts);
        let current = self.status(ts);
        if !known || status <= current {
            return false;
        }
        self.states.insert(ts, status);
        self.save();
        true
    }
}
