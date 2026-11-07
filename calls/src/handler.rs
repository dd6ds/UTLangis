//! RingRTC's callbacks: signalling messages to send and call states, passed
//! to the app as JSON events. When RingRTC asks to proceed with a new call,
//! the handler hands it our media and the TURN servers.

use std::collections::{HashMap, HashSet};
use std::ffi::{c_char, c_void, CString};
use std::sync::{Arc, Mutex};

use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine as _;
use serde_json::{json, Value};

use ringrtc::common::{CallConfig, CallId, CallMediaType, DeviceId, Result as RtcResult};
use ringrtc::core::call_manager::CallManager;
use ringrtc::core::group_call;
use ringrtc::core::signaling::{self, SenderStatus};
use ringrtc::lite::http;
use ringrtc::lite::sfu::UserId;
use ringrtc::native::{
    CallState, CallStateHandler, GroupUpdate, GroupUpdateHandler, NativeCallContext,
    NativePlatform, SignalingSender,
};
use ringrtc::webrtc::media::{AudioTrack, VideoSource, VideoTrack};
use ringrtc::webrtc::peer_connection::AudioLevel;
use ringrtc::webrtc::peer_connection_factory::IceServer;
use ringrtc::webrtc::peer_connection_observer::NetworkRoute;

use crate::video::RemoteVideo;

pub type EventCallback = extern "C" fn(context: *mut c_void, json: *const c_char);

/// Passes events to the app. The C side keeps `context` valid while calls run.
pub struct Sink {
    pub callback: EventCallback,
    pub context: usize,
}

impl Sink {
    pub fn emit(&self, event: Value) {
        if let Ok(text) = CString::new(event.to_string()) {
            (self.callback)(self.context as *mut c_void, text.as_ptr());
        }
    }
}

/// Our side of a call: microphone, camera, and the TURN servers.
pub struct Media {
    pub audio: AudioTrack,
    /// The user muted the microphone.
    pub muted: bool,
    pub video: VideoTrack,
    pub video_source: VideoSource,
    pub camera: bool,
    pub remote_video: RemoteVideo,
    pub ice_servers: Vec<IceServer>,
}

pub type Manager = CallManager<NativePlatform>;

#[derive(Clone)]
pub struct Handler {
    pub sink: Arc<Sink>,
    pub media: Arc<Mutex<Media>>,
    /// Set right after the CallManager exists (it needs the handler first).
    pub manager: Arc<Mutex<Option<Manager>>>,
}

/// Tells the other side whether our camera is on.
pub fn send_camera_state(manager: &Manager, camera: bool) {
    if let Ok(mut connection) = manager.active_connection() {
        let status = SenderStatus { video_enabled: Some(camera), ..Default::default() };
        let _ = connection.update_sender_status(status);
    }
}

fn b64(bytes: &[u8]) -> Value {
    BASE64.encode(bytes).into()
}

/// The fields of a signalling message in a "signal" event.
fn describe(event: &mut Value, message: signaling::Message) {
    match message {
        signaling::Message::Offer(offer) => {
            event["kind"] = "offer".into();
            event["video"] = (offer.call_media_type == CallMediaType::Video).into();
            event["opaque"] = b64(&offer.opaque);
        }
        signaling::Message::Answer(answer) => {
            event["kind"] = "answer".into();
            event["opaque"] = b64(&answer.opaque);
        }
        signaling::Message::Ice(ice) => {
            event["kind"] = "ice".into();
            event["candidates"] = ice.candidates.iter().map(|c| b64(&c.opaque)).collect();
        }
        signaling::Message::Hangup(hangup) => {
            let (kind, device) = hangup.to_type_and_device_id();
            event["kind"] = "hangup".into();
            event["type"] = (kind as i32).into();
            event["hangupDeviceId"] = device.unwrap_or(0).into();
        }
        signaling::Message::Busy => event["kind"] = "busy".into(),
    }
}

impl Handler {
    /// RingRTC waits for our media and TURN servers before it connects a
    /// new call.
    fn proceed(&self, call_id: CallId) {
        let media = self.media.lock().unwrap();
        let context = NativeCallContext::new(
            false,
            media.ice_servers.clone(),
            media.audio.clone(),
            media.video.clone(),
            Box::new(media.remote_video.clone()),
        );
        drop(media);
        if let Some(manager) = self.manager.lock().unwrap().as_mut() {
            manager.proceed(call_id, context, CallConfig::default(), None);
        }
    }

    /// The microphone (and the camera if on) go live once the call is
    /// connected.
    fn go_live(&self) {
        let media = self.media.lock().unwrap();
        media.audio.set_enabled(!media.muted);
        media.video.set_enabled(media.camera);
        let camera = media.camera;
        drop(media);
        if let Some(manager) = self.manager.lock().unwrap().as_ref() {
            send_camera_state(manager, camera);
        }
    }
}

impl SignalingSender for Handler {
    fn send_signaling(
        &self,
        recipient_id: &str,
        call_id: CallId,
        receiver_device_id: Option<DeviceId>,
        message: signaling::Message,
    ) -> RtcResult<()> {
        let mut event = json!({ "ev": "signal", "peer": recipient_id,
                                "callId": call_id.as_u64().to_string() });
        if let Some(device) = receiver_device_id {
            event["deviceId"] = device.into();
        }
        describe(&mut event, message);
        self.sink.emit(event);
        Ok(())
    }

    fn send_call_message(
        &self,
        _recipient_id: UserId,
        _message: Vec<u8>,
        _urgency: group_call::SignalingMessageUrgency,
    ) -> RtcResult<()> {
        Ok(())
    }

    fn send_call_message_to_group(
        &self,
        _group_id: group_call::GroupId,
        _message: Vec<u8>,
        _urgency: group_call::SignalingMessageUrgency,
        _recipients_override: HashSet<UserId>,
    ) -> RtcResult<()> {
        Ok(())
    }

    fn send_call_message_to_adhoc_group(
        &self,
        _message: Vec<u8>,
        _urgency: group_call::SignalingMessageUrgency,
        _expiration: u64,
        _recipients_to_endorsements: HashMap<UserId, Vec<u8>>,
    ) -> RtcResult<()> {
        Ok(())
    }
}

/// The name of a call state in "state" events.
fn state_name(state: &CallState) -> &'static str {
    match state {
        CallState::Incoming(_) => "incoming",
        CallState::Outgoing(_) => "outgoing",
        CallState::Ringing => "ringing",
        CallState::Connected => "connected",
        CallState::Connecting => "connecting",
        CallState::Ended(..) => "ended",
        CallState::Rejected(_) => "rejected",
        CallState::Concluded => "concluded",
    }
}

impl CallStateHandler for Handler {
    fn handle_call_state(&self, remote_peer_id: &str, call_id: CallId, state: CallState)
        -> RtcResult<()> {
        let mut event = json!({ "ev": "state", "peer": remote_peer_id,
                                "callId": call_id.as_u64().to_string(),
                                "state": state_name(&state) });
        match &state {
            CallState::Incoming(media) | CallState::Outgoing(media) => {
                event["video"] = (*media == CallMediaType::Video).into();
                self.proceed(call_id);
            }
            CallState::Connected => self.go_live(),
            CallState::Ended(reason, _) => event["reason"] = format!("{reason:?}").into(),
            CallState::Rejected(reason) => event["reason"] = reason.to_string().into(),
            _ => {}
        }
        self.sink.emit(event);
        Ok(())
    }

    fn handle_remote_audio_state(&self, remote_peer_id: &str, enabled: bool) -> RtcResult<()> {
        self.sink.emit(json!({ "ev": "remoteAudio", "peer": remote_peer_id, "enabled": enabled }));
        Ok(())
    }

    fn handle_remote_video_state(&self, remote_peer_id: &str, enabled: bool) -> RtcResult<()> {
        self.sink.emit(json!({ "ev": "remoteVideo", "peer": remote_peer_id, "enabled": enabled }));
        Ok(())
    }

    fn handle_remote_sharing_screen(&self, _remote_peer_id: &str, _enabled: bool)
        -> RtcResult<()> {
        Ok(())
    }

    fn handle_network_route(&self, _remote_peer_id: &str, route: NetworkRoute) -> RtcResult<()> {
        log::info!("network route: relayed {}", route.local_relayed || route.remote_relayed);
        Ok(())
    }

    fn handle_audio_levels(&self, _peer: &str, _captured: AudioLevel, _received: AudioLevel)
        -> RtcResult<()> {
        Ok(())
    }

    fn handle_low_bandwidth_for_video(&self, _remote_peer_id: &str, _recovered: bool)
        -> RtcResult<()> {
        Ok(())
    }
}

/// Group calls are not supported.
impl GroupUpdateHandler for Handler {
    fn handle_group_update(&self, _update: GroupUpdate) -> RtcResult<()> {
        Ok(())
    }
}

/// HTTP for group calls, which are not supported: requests stay unanswered.
pub struct NoHttp;

impl http::Delegate for NoHttp {
    fn send_request(&self, _request_id: u32, _request: http::Request) {}
}
