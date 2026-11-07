//! One person, two chats: a chat started with someone's phone number
//! identity (PNI) and the chat their replies arrive in, under their account
//! id (ACI). The PNI chat is moved into the ACI chat: when a reply proves
//! the link, when both chats have the same name, or when the user joins
//! them by hand.

use presage::libsignal_service::protocol::ServiceId;
use presage::store::{ContentsStore, Thread};
use serde_json::json;

use crate::threads::{parse_thread_key, thread_key};
use crate::titles::SignalManager;
use crate::worker::{threads_event, Shared};

/// Joins chats that are evidently the same person (ThreadIndex::
/// duplicate_pairs), e.g. after a reply that did not prove the link.
pub async fn merge_duplicates(manager: &mut SignalManager, shared: &Shared) {
    let pairs = shared.index.borrow().duplicate_pairs();
    for (pni, aci) in pairs {
        tracing::info!("joining a phone number chat into the account's chat of the same name");
        merge_pni_thread(manager, shared, pni, aci).await;
    }
}

/// The user joined the phone number chat `from` with the chat `to`.
pub async fn merge_chats(manager: &mut SignalManager, shared: &Shared, from: &str, to: &str) {
    match (parse_thread_key(from), parse_thread_key(to)) {
        (Some(Thread::Contact(pni)), Some(Thread::Contact(aci))) if pni != aci => {
            merge_pni_thread(manager, shared, pni, aci).await
        }
        _ => shared.sink.error("mergeChats", "not two one-to-one chats"),
    }
}

/// Moves the messages of the PNI chat into the ACI chat so the conversation
/// is one chat again, and tells the app (event "merged") to switch if that
/// chat is open.
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
    shared.calls.borrow_mut().rename_thread(&from_key, &to_key);
    shared.sink.emit(json!({ "ev": "merged", "from": from_key, "to": to_key }));
    shared.sink.emit(threads_event(shared));
}
