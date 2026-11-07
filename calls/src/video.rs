//! Video of a call: the other side's pictures go to the app as RGBA (through
//! the callback of `ut_calls_set_video_callback`), camera pictures from the
//! app go to WebRTC.

use std::ffi::c_void;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use ringrtc::lite::sfu::DemuxId;
use ringrtc::webrtc::media::{VideoFrame, VideoPixelFormat, VideoSink, VideoSource};

/// A picture of the other side: RGBA, `width` × `height`.
pub type FrameCallback =
    extern "C" fn(context: *mut c_void, width: u32, height: u32, rgba: *const u8);

pub static FRAME_CALLBACK: Mutex<Option<(FrameCallback, usize)>> = Mutex::new(None);

/// Largest side of pictures handed to the app; more is not needed on a phone.
const MAX_REMOTE_SIDE: u32 = 960;
/// Pictures handed to the app per second, at most.
const MAX_REMOTE_FPS: u64 = 20;

#[derive(Clone, Default)]
pub struct RemoteVideo {
    last: Arc<Mutex<Option<Instant>>>,
}

impl RemoteVideo {
    /// Whether enough time passed since the last picture handed on.
    fn due(&self) -> bool {
        let mut last = self.last.lock().unwrap();
        let now = Instant::now();
        let gap = Duration::from_millis(1000 / MAX_REMOTE_FPS);
        if last.is_some_and(|previous| now - previous < gap) {
            return false;
        }
        *last = Some(now);
        true
    }
}

/// The frame upright and at most MAX_REMOTE_SIDE wide or high (even sizes).
fn for_display(frame: VideoFrame) -> VideoFrame {
    let frame = frame.apply_rotation();
    let largest = frame.width().max(frame.height());
    if largest <= MAX_REMOTE_SIDE {
        return frame;
    }
    let width = (frame.width() * MAX_REMOTE_SIDE / largest).max(2) & !1;
    let height = (frame.height() * MAX_REMOTE_SIDE / largest).max(2) & !1;
    frame.scale(width, height)
}

impl VideoSink for RemoteVideo {
    fn on_video_frame(&self, _demux_id: DemuxId, frame: VideoFrame) {
        if frame.width() == 0 || frame.height() == 0 || !self.due() {
            return;
        }
        let Some((callback, context)) = *FRAME_CALLBACK.lock().unwrap() else {
            return;
        };
        let frame = for_display(frame);
        let (width, height) = (frame.width(), frame.height());
        let mut rgba = vec![0u8; (width * height * 4) as usize];
        if frame.to_rgba(&mut rgba) {
            callback(context as *mut c_void, width, height, rgba.as_ptr());
        }
    }

    fn box_clone(&self) -> Box<dyn VideoSink> {
        Box::new(self.clone())
    }
}

/// Sends one camera picture (RGBA).
pub fn push(source: &VideoSource, width: u32, height: u32, rgba: &[u8]) {
    source.push_frame(VideoFrame::copy_from_slice(width, height, VideoPixelFormat::Rgba, rgba));
}
