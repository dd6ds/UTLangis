//! The stored messages of one conversation, as the app shows them when it is
//! opened: oldest first, edits and reactions applied to the messages they
//! belong to.

use std::collections::HashMap;

use presage::libsignal_service::content::Content;
use presage::libsignal_service::protocol::ServiceId;
use presage::store::{ContentExt, ContentsStore, Thread};
use serde_json::{json, Value};

use crate::convert;
use crate::events::message_json;
use crate::files;
use crate::threads::parse_thread_key;
use crate::titles::{self, SignalManager};
use crate::worker::Shared;

/// Messages handed to the app when a conversation is opened.
const HISTORY_LIMIT: usize = 300;

pub async fn history(manager: &mut SignalManager, shared: &Shared, key: &str) {
    let Some(thread) = parse_thread_key(key) else {
        return shared.sink.error("history", "invalid conversation");
    };
    let own: ServiceId = manager.registration_data().service_ids.aci().into();
    let mut contents: Vec<Content> = match manager.store().messages(&thread, ..).await {
        Ok(iter) => iter.filter_map(Result::ok).collect(),
        Err(error) => return shared.sink.error("history", error),
    };
    // The store hands them out newest first; the chat reads top to bottom,
    // and later edits and reactions must override earlier ones.
    contents.sort_by_key(|content| content.timestamp());

    let views: Vec<_> = contents.iter().filter_map(|c| convert::view(c, &own)).collect();
    let mut reactions = reactions_by_message(&contents, &own);
    let edits = edits_by_message(&contents);
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
        if let Some(text) = edits.get(&view.ts) {
            row["text"] = text.as_str().into();
            row["edited"] = true.into();
        }
        rows.push(row);
    }
    // Calls are kept apart from the messages; the app sorts by time.
    rows.extend(shared.calls.borrow().rows(key));
    shared.sink.emit(json!({ "ev": "history", "thread": key, "messages": rows }));
}

/// Reactions are stored as messages of their own: per message, the latest
/// one of each reactor counts, and a removal takes it back.
fn reactions_by_message(
    contents: &[Content],
    own: &ServiceId,
) -> HashMap<u64, serde_json::Map<String, Value>> {
    let mut reactions: HashMap<u64, serde_json::Map<String, Value>> = HashMap::new();
    for reaction in contents.iter().filter_map(|c| convert::reaction(c, own)) {
        let entry = reactions.entry(reaction.target).or_default();
        if reaction.remove {
            entry.remove(&reaction.reactor);
        } else {
            entry.insert(reaction.reactor, reaction.emoji.into());
        }
    }
    reactions
}

/// The current text of each changed message: that of its latest edit.
fn edits_by_message(contents: &[Content]) -> HashMap<u64, String> {
    let mut latest: HashMap<u64, convert::EditView> = HashMap::new();
    for edit in contents.iter().filter_map(convert::edit) {
        let newer = latest.get(&edit.target).map_or(true, |known| edit.ts >= known.ts);
        if newer {
            latest.insert(edit.target, edit);
        }
    }
    latest.into_iter().map(|(target, edit)| (target, edit.text)).collect()
}
