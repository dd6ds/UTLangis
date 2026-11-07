//! The signalling of calls, which run in libutlangis_calls (Signal's
//! RingRTC). The backend only carries the messages: received CallMessages go
//! to the app as "callSignal" events, with the identity keys RingRTC binds
//! the call's encryption to, and the app's "sendCallSignal" commands go out
//! as CallMessages. Opaque payloads travel as base64.

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use presage::libsignal_service::content::Content;
use presage::libsignal_service::protocol::{
    IdentityKey, IdentityKeyStore, ProtocolAddress, ServiceId,
};
use presage::proto::call_message::{
    hangup::Type as HangupType, offer::Type as OfferType, Answer, Busy, Hangup, IceUpdate, Offer,
};
use presage::proto::CallMessage;
use presage::store::{Store, Thread};
use serde_json::{json, Value};

use crate::commands::now_millis;
use crate::threads::thread_key;
use crate::titles::SignalManager;
use crate::worker::Shared;

/// An identity key as RingRTC wants it: the 32 key bytes, without the type
/// byte in front.
fn key_bytes(key: &IdentityKey) -> Vec<u8> {
    key.serialize().get(1..).map(<[u8]>::to_vec).unwrap_or_default()
}

fn b64(bytes: Option<&[u8]>) -> Value {
    BASE64.encode(bytes.unwrap_or_default()).into()
}

/// Our identity key and the sender's, which offers and answers need.
async fn add_keys(manager: &SignalManager, content: &Content, event: &mut Value) -> bool {
    let store = manager.store().aci_protocol_store();
    let own = store.get_identity_key_pair().await.ok().map(|pair| key_bytes(pair.identity_key()));
    let device = content.metadata.sender_device;
    let address = ProtocolAddress::new(content.metadata.sender.service_id_string(), device);
    let theirs = store.get_identity(&address).await.ok().flatten().map(|key| key_bytes(&key));
    let (Some(own), Some(theirs)) = (own, theirs) else {
        return false;
    };
    event["receiverKey"] = BASE64.encode(own).into();
    event["senderKey"] = BASE64.encode(theirs).into();
    event["localDeviceId"] = u32::from(manager.device_id()).into();
    true
}

/// Kind, call id and payload of a received CallMessage; false for messages
/// that carry none of them.
fn describe(call: &CallMessage, event: &mut Value) -> bool {
    let (kind, id) = if let Some(offer) = &call.offer {
        event["video"] = (offer.r#type == Some(OfferType::OfferVideoCall as i32)).into();
        event["opaque"] = b64(offer.opaque.as_deref());
        ("offer", offer.id)
    } else if let Some(answer) = &call.answer {
        event["opaque"] = b64(answer.opaque.as_deref());
        ("answer", answer.id)
    } else if let Some(first) = call.ice_update.first() {
        event["candidates"] =
            call.ice_update.iter().map(|ice| b64(ice.opaque.as_deref())).collect();
        ("ice", first.id)
    } else if let Some(hangup) = &call.hangup {
        event["type"] = hangup.r#type.unwrap_or_default().into();
        event["hangupDeviceId"] = hangup.device_id.unwrap_or_default().into();
        ("hangup", hangup.id)
    } else if let Some(busy) = &call.busy {
        ("busy", busy.id)
    } else {
        return false;
    };
    event["kind"] = kind.into();
    event["callId"] = id.unwrap_or_default().to_string().into();
    true
}

/// Hands a received CallMessage to the app for RingRTC.
pub async fn forward(
    manager: &mut SignalManager,
    shared: &Shared,
    content: &Content,
    call: &CallMessage,
) {
    let sender = content.metadata.sender;
    let sent = content.metadata.server_timestamp.timestamp_millis().max(0) as u64;
    let mut event = json!({ "ev": "callSignal", "peer": sender.service_id_string(),
                            "thread": thread_key(&Thread::Contact(sender)),
                            "deviceId": u32::from(content.metadata.sender_device),
                            "ageSecs": now_millis().saturating_sub(sent) / 1000 });
    if !describe(call, &mut event) {
        return;
    }
    let needs_keys = call.offer.is_some() || call.answer.is_some();
    if needs_keys && !add_keys(manager, content, &mut event).await {
        return tracing::warn!("call signal without identity keys; ignored");
    }
    shared.sink.emit(event);
}

fn opaque(signal: &Value) -> Option<Vec<u8>> {
    signal["opaque"].as_str().and_then(|text| BASE64.decode(text).ok())
}

/// The CallMessage for a signalling message RingRTC produced.
fn build(signal: &Value, id: u64) -> Result<CallMessage, String> {
    let mut message = CallMessage {
        destination_device_id: signal["deviceId"].as_u64().map(|d| d as u32),
        ..Default::default()
    };
    match signal["kind"].as_str().unwrap_or_default() {
        "offer" => {
            let video = signal["video"].as_bool().unwrap_or(false);
            let kind = if video { OfferType::OfferVideoCall } else { OfferType::OfferAudioCall };
            message.offer =
                Some(Offer { id: Some(id), r#type: Some(kind as i32), opaque: opaque(signal) });
        }
        "answer" => message.answer = Some(Answer { id: Some(id), opaque: opaque(signal) }),
        "ice" => {
            let candidates = signal["candidates"].as_array().cloned().unwrap_or_default();
            message.ice_update = candidates
                .iter()
                .filter_map(|c| c.as_str().and_then(|text| BASE64.decode(text).ok()))
                .map(|bytes| IceUpdate { id: Some(id), opaque: Some(bytes) })
                .collect();
        }
        "hangup" => {
            message.hangup = Some(Hangup {
                id: Some(id),
                r#type: Some(signal["type"].as_i64().unwrap_or(HangupType::HangupNormal as i64)
                    as i32),
                device_id: signal["hangupDeviceId"].as_u64().map(|d| d as u32),
            });
        }
        "busy" => message.busy = Some(Busy { id: Some(id) }),
        other => return Err(format!("unknown kind {other}")),
    }
    Ok(message)
}

/// Sends a signalling message RingRTC produced ({peer, callId, kind, ...}
/// as libutlangis_calls emits it).
pub async fn send(manager: &mut SignalManager, shared: &Shared, signal: &Value) {
    let Some(peer) = signal["peer"].as_str().and_then(ServiceId::parse_from_service_id_string)
    else {
        return shared.sink.error("sendCallSignal", "invalid peer");
    };
    let Some(id) = signal["callId"].as_str().and_then(|text| text.parse::<u64>().ok()) else {
        return shared.sink.error("sendCallSignal", "invalid call id");
    };
    let message = match build(signal, id) {
        Ok(message) => message,
        Err(error) => return shared.sink.error("sendCallSignal", error),
    };
    if let Err(error) = manager.send_message(peer, message, now_millis()).await {
        shared.sink.error("sendCallSignal", error);
    }
}

/// Short-lived TURN servers for the next call ("turnServers" event).
pub async fn turn_servers(manager: &mut SignalManager, shared: &Shared) {
    let relays = match manager.calling_relays().await {
        Ok(relays) => relays,
        Err(error) => return shared.sink.error("turnServers", error),
    };
    let mut servers = Vec::new();
    for relay in relays {
        servers.push(json!({ "username": relay.username, "password": relay.password,
                             "hostname": "", "urls": relay.urls }));
        // Addresses as IPs, validated against the hostname.
        if let (Some(hostname), false) = (&relay.hostname, relay.urls_with_ips.is_empty()) {
            servers.push(json!({ "username": relay.username, "password": relay.password,
                                 "hostname": hostname, "urls": relay.urls_with_ips }));
        }
    }
    shared.sink.emit(json!({ "ev": "turnServers", "servers": servers,
                             "localDeviceId": u32::from(manager.device_id()) }));
}
