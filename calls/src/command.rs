//! The commands of `ut_calls_command` (JSON from the app): received
//! signalling for RingRTC, starting, answering and ending calls, microphone
//! and camera, TURN servers.

use std::time::Duration;

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use serde_json::Value;

use ringrtc::common::{CallId, CallMediaType, DeviceId};
use ringrtc::core::signaling::{
    Answer, Hangup, HangupType, Ice, IceCandidate, Offer, ReceivedAnswer, ReceivedBusy,
    ReceivedHangup, ReceivedIce, ReceivedOffer,
};
use ringrtc::webrtc::peer_connection_factory::IceServer;

use crate::handler::{send_camera_state, Media};
use crate::Engine;

fn text(value: &Value, key: &str) -> String {
    value.get(key).and_then(Value::as_str).unwrap_or_default().to_owned()
}

fn number(value: &Value, key: &str) -> u64 {
    value.get(key).and_then(Value::as_u64).unwrap_or_default()
}

fn bytes(value: &Value) -> Vec<u8> {
    value.as_str().and_then(|s| BASE64.decode(s).ok()).unwrap_or_default()
}

/// Signal call ids are 64-bit numbers; JSON carries them as text.
fn call_id(command: &Value) -> Result<CallId, String> {
    command["callId"]
        .as_str()
        .and_then(|s| s.parse::<u64>().ok())
        .map(CallId::new)
        .ok_or_else(|| "invalid callId".to_owned())
}

fn media_type(command: &Value) -> CallMediaType {
    if command["video"].as_bool().unwrap_or(false) {
        CallMediaType::Video
    } else {
        CallMediaType::Audio
    }
}

fn ice_servers(command: &Value) -> Vec<IceServer> {
    let servers = command["servers"].as_array().cloned().unwrap_or_default();
    servers
        .iter()
        .map(|server| {
            let urls = server["urls"]
                .as_array()
                .map(|list| list.iter().filter_map(|u| u.as_str().map(str::to_owned)).collect())
                .unwrap_or_default();
            IceServer::new(text(server, "username"), text(server, "password"),
                           text(server, "hostname"), urls)
        })
        .collect()
}

fn received(engine: &mut Engine, cmd: &str, command: &Value) -> Result<(), String> {
    let peer = text(command, "peer");
    let id = call_id(command)?;
    let device = number(command, "deviceId") as DeviceId;
    let manager = &mut engine.manager;
    match cmd {
        "receivedOffer" => {
            let offer = Offer::new(media_type(command), bytes(&command["opaque"]))
                .map_err(|e| e.to_string())?;
            manager.received_offer(peer, id, ReceivedOffer {
                offer,
                age: Duration::from_secs(number(command, "ageSecs")),
                sender_device_id: device,
                receiver_device_id: number(command, "localDeviceId") as DeviceId,
                sender_identity_key: bytes(&command["senderKey"]),
                receiver_identity_key: bytes(&command["receiverKey"]),
            });
        }
        "receivedAnswer" => {
            let answer = Answer::new(bytes(&command["opaque"])).map_err(|e| e.to_string())?;
            manager.received_answer(peer, id, ReceivedAnswer {
                answer,
                sender_device_id: device,
                sender_identity_key: bytes(&command["senderKey"]),
                receiver_identity_key: bytes(&command["receiverKey"]),
            });
        }
        "receivedIce" => {
            let candidates = command["candidates"]
                .as_array()
                .map(|list| list.iter().map(|c| IceCandidate::new(bytes(c))).collect())
                .unwrap_or_default();
            let ice = ReceivedIce { ice: Ice { candidates }, sender_device_id: device };
            manager.received_ice(peer, id, ice);
        }
        "receivedHangup" => {
            let kind = HangupType::from_i32(number(command, "type") as i32)
                .unwrap_or(HangupType::Normal);
            let hangup = Hangup::from_type_and_device_id(
                kind, number(command, "hangupDeviceId") as DeviceId);
            manager.received_hangup(peer, id, ReceivedHangup { hangup, sender_device_id: device });
        }
        _ => manager.received_busy(peer, id, ReceivedBusy { sender_device_id: device }),
    }
    Ok(())
}

fn set_camera(engine: &mut Engine, on: bool) {
    {
        let mut media = engine.media.lock().unwrap();
        media.camera = on;
        media.video.set_enabled(on);
    }
    send_camera_state(&engine.manager, on);
}

fn set_muted(media: &mut Media, muted: bool) {
    media.muted = muted;
    media.audio.set_enabled(!muted);
}

pub fn run(engine: &mut Engine, command: &Value) -> Result<(), String> {
    let cmd = text(command, "cmd");
    match cmd.as_str() {
        "iceServers" => engine.media.lock().unwrap().ice_servers = ice_servers(command),
        "receivedOffer" | "receivedAnswer" | "receivedIce" | "receivedHangup" | "receivedBusy" => {
            received(engine, &cmd, command)?
        }
        "call" => engine.manager.create_outgoing_call(
            text(command, "peer"),
            call_id(command)?,
            media_type(command),
            number(command, "localDeviceId") as DeviceId,
        ),
        "accept" => engine.manager.accept_call(call_id(command)?),
        "hangup" => engine.manager.hangup(),
        "camera" => set_camera(engine, command["enabled"].as_bool().unwrap_or(false)),
        "mute" => {
            let muted = command["muted"].as_bool().unwrap_or(false);
            set_muted(&mut engine.media.lock().unwrap(), muted);
        }
        other => return Err(format!("unknown command {other}")),
    }
    Ok(())
}
