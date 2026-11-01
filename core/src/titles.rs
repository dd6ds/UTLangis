//! Display names for conversations. A primary device has no synced address
//! book, so contact names come from the Signal profiles people publish.

use std::collections::HashMap;

use presage::libsignal_service::profile_name::ProfileName;
use presage::libsignal_service::protocol::ServiceId;
use presage::manager::Registered;
use presage::store::{ContentsStore, Thread};
use presage::Manager;
use presage_store_sqlite::SqliteStore;

pub type SignalManager = Manager<SqliteStore, Registered>;

/// The name to show for a thread, or an empty string if none is known yet.
pub async fn thread_title(manager: &mut SignalManager, thread: &Thread) -> String {
    match thread {
        Thread::Group(key) => {
            manager.store().group(*key).await.ok().flatten().map(|g| g.title).unwrap_or_default()
        }
        Thread::Contact(id) => contact_name(manager, id).await,
    }
}

pub async fn contact_name(manager: &mut SignalManager, id: &ServiceId) -> String {
    if let Ok(Some(contact)) = manager.store().contact_by_id(id).await {
        if !contact.name.is_empty() {
            return contact.name;
        }
    }
    // Profiles can only be decrypted with the key the person shared with us
    // in one of their messages.
    let ServiceId::Aci(aci) = id else {
        return String::new();
    };
    let Ok(Some(key)) = manager.store().profile_key(id).await else {
        return String::new();
    };
    match manager.retrieve_profile_by_uuid(*aci, key).await {
        Ok(profile) => profile.name.map(|name| full_name(&name)).unwrap_or_default(),
        Err(error) => {
            tracing::info!(%error, "profile not available");
            String::new()
        }
    }
}

/// contact_name with a cache, for many messages from the same people.
pub async fn cached_name(
    manager: &mut SignalManager,
    id: &ServiceId,
    cache: &mut HashMap<String, String>,
) -> String {
    let key = id.service_id_string();
    if let Some(name) = cache.get(&key) {
        return name.clone();
    }
    let name = contact_name(manager, id).await;
    cache.insert(key, name.clone());
    name
}

fn full_name(name: &ProfileName<String>) -> String {
    match &name.family_name {
        Some(family) if !family.is_empty() => format!("{} {}", name.given_name, family),
        _ => name.given_name.clone(),
    }
}
