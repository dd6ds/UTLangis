//! One-to-one Signal calls for UT Langis, on Signal's RingRTC (WebRTC).
//!
//! RingRTC runs the call: media, encryption, ICE. It does not talk to the
//! Signal servers; the app carries the call's signalling messages (offer,
//! answer, ICE candidates, hang-up, busy) between RingRTC and the Signal
//! backend (libutlangis_core), which sends and receives them as
//! CallMessages.
//!
//! C interface (include/utlangis_calls.h):
//! - `ut_calls_start(callback, context)`: sets up WebRTC and the audio
//!   devices. Events arrive through `callback` as JSON, on RingRTC's threads.
//! - `ut_calls_command(json)`: see command.rs.
//! - `ut_calls_set_video_callback(callback, context)`: the other side's
//!   pictures; `ut_calls_push_frame(width, height, rgba)`: a camera picture.
//! - `ut_calls_stop()`.
//!
//! Events: `signal` (a signalling message to send: kind offer / answer /
//! ice / hangup / busy), `state` (incoming, outgoing, ringing, connected,
//! connecting, ended, rejected, concluded), `remoteAudio` and `remoteVideo`
//! {enabled}.

mod command;
mod handler;
mod video;

use std::ffi::{c_char, c_void, CStr};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::Value;

use ringrtc::common::Result as RtcResult;
use ringrtc::core::call_manager::CallManager;
use ringrtc::lite::http;
use ringrtc::native::NativePlatform;
use ringrtc::webrtc::peer_connection_factory::{AudioConfig, PeerConnectionFactory};

use handler::{EventCallback, Handler, Manager, Media, NoHttp, Sink};
use video::{FrameCallback, RemoteVideo, FRAME_CALLBACK};

pub struct Engine {
    manager: Manager,
    media: Arc<Mutex<Media>>,
    _factory: PeerConnectionFactory,
}

static ENGINE: Mutex<Option<Engine>> = Mutex::new(None);

/// How long to wait for PulseAudio to list the audio devices.
const DEVICE_WAIT_STEPS: u32 = 30;
const DEVICE_WAIT_STEP: Duration = Duration::from_millis(100);

/// Our messages at info level; RingRTC's own ones only from warnings on (it
/// logs every ICE candidate at info level).
struct Logger;

impl log::Log for Logger {
    fn enabled(&self, metadata: &log::Metadata) -> bool {
        let ours = metadata.target().starts_with("utlangis_calls");
        metadata.level() <= if ours { log::Level::Info } else { log::Level::Warn }
    }
    fn log(&self, record: &log::Record) {
        if self.enabled(record.metadata()) {
            eprintln!("utlangis-calls [{}] {}", record.level(), record.args());
        }
    }
    fn flush(&self) {}
}

static LOGGER: Logger = Logger;

/// Picks the system's default speaker and microphone (PulseAudio's default
/// sink and source). WebRTC plays and records nothing until devices are set.
fn choose_audio_devices(factory: &mut PeerConnectionFactory) {
    for _ in 0..DEVICE_WAIT_STEPS {
        let playout = factory.get_audio_playout_devices().ok()
            .and_then(|list| list.default.default_for_voip());
        let recording = factory.get_audio_recording_devices().ok()
            .and_then(|list| list.default.default_for_voip());
        if let (Some(playout), Some(recording)) = (playout, recording) {
            log::info!("audio devices: {} / {}", playout.name, recording.name);
            if let Err(error) = factory.set_audio_playout_device_by_id(&playout.unique_id, 0) {
                log::warn!("could not use the speaker: {error:?}");
            }
            if let Err(error) = factory.set_audio_recording_device_by_id(&recording.unique_id, 0) {
                log::warn!("could not use the microphone: {error:?}");
            }
            return;
        }
        std::thread::sleep(DEVICE_WAIT_STEP);
    }
    log::warn!("no audio devices found");
}

fn start(sink: Arc<Sink>) -> RtcResult<Engine> {
    let mut factory = PeerConnectionFactory::new(&AudioConfig::default(), false, "", None)?;
    choose_audio_devices(&mut factory);
    let audio = factory.create_outgoing_audio_track()?;
    let video_source = factory.create_outgoing_video_source()?;
    let video = factory.create_outgoing_video_track(&video_source)?;
    video.set_enabled(false);
    let media = Arc::new(Mutex::new(Media {
        audio,
        muted: false,
        video,
        video_source,
        camera: false,
        remote_video: RemoteVideo::default(),
        ice_servers: Vec::new(),
    }));
    let handler = Handler { sink, media: media.clone(), manager: Arc::new(Mutex::new(None)) };
    let platform = NativePlatform::new(
        factory.clone(),
        Box::new(handler.clone()),
        true,
        Box::new(handler.clone()),
        Box::new(handler.clone()),
    );
    let manager = CallManager::new(platform, http::DelegatingClient::new(NoHttp))?;
    *handler.manager.lock().unwrap() = Some(manager.clone());
    Ok(Engine { manager, media, _factory: factory })
}

/// Sets up WebRTC and the audio devices. Returns false on failure (see the
/// log). `callback` gets the events as JSON, on RingRTC's threads.
#[no_mangle]
pub extern "C" fn ut_calls_start(callback: EventCallback, context: *mut c_void) -> bool {
    let _ = log::set_logger(&LOGGER).map(|()| log::set_max_level(log::LevelFilter::Info));
    let mut engine = ENGINE.lock().unwrap();
    if engine.is_some() {
        return true;
    }
    match start(Arc::new(Sink { callback, context: context as usize })) {
        Ok(started) => {
            *engine = Some(started);
            true
        }
        Err(error) => {
            log::error!("could not start calls: {error:?}");
            false
        }
    }
}

/// Runs one command (JSON). Errors are logged.
///
/// # Safety
/// `json` must be a valid NUL-terminated string.
#[no_mangle]
pub unsafe extern "C" fn ut_calls_command(json: *const c_char) {
    if json.is_null() {
        return;
    }
    let Ok(command) = serde_json::from_slice::<Value>(CStr::from_ptr(json).to_bytes()) else {
        return log::warn!("invalid command");
    };
    let mut engine = ENGINE.lock().unwrap();
    let Some(engine) = engine.as_mut() else {
        return log::warn!("calls not started");
    };
    if let Err(error) = command::run(engine, &command) {
        log::warn!("command failed: {error}");
    }
}

/// Where the other side's video goes (RGBA pictures, on a WebRTC thread).
#[no_mangle]
pub extern "C" fn ut_calls_set_video_callback(callback: FrameCallback, context: *mut c_void) {
    *FRAME_CALLBACK.lock().unwrap() = Some((callback, context as usize));
}

/// Sends a camera picture (RGBA, `width` × `height`) while the camera is on.
///
/// # Safety
/// `rgba` must point to `width * height * 4` bytes.
#[no_mangle]
pub unsafe extern "C" fn ut_calls_push_frame(width: u32, height: u32, rgba: *const u8) {
    if rgba.is_null() || width == 0 || height == 0 {
        return;
    }
    let data = std::slice::from_raw_parts(rgba, (width * height * 4) as usize);
    let engine = ENGINE.lock().unwrap();
    if let Some(engine) = engine.as_ref() {
        let media = engine.media.lock().unwrap();
        if media.camera {
            video::push(&media.video_source, width, height, data);
        }
    }
}

/// Ends any call and releases WebRTC.
#[no_mangle]
pub extern "C" fn ut_calls_stop() {
    if let Some(mut engine) = ENGINE.lock().unwrap().take() {
        engine.manager.hangup();
        let _ = engine.manager.close();
    }
}
