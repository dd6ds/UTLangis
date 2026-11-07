//! Other devices of our account (Signal Desktop, tablets): reading the
//! linking QR code they show, linking them, listing and unlinking them.
//! Only the primary device (registered with the phone number) can do this.

use std::path::{Path, PathBuf};

use serde_json::json;
use url::Url;

use crate::titles::SignalManager;
use crate::worker::Shared;

/// The scanner page's aiming frame covers the middle of the picture; only
/// this share of the shorter side, around the centre, is searched.
const SCAN_CROP: f32 = 0.85;

/// Longest side (pixels) the cropped photo is searched at, small first
/// because that is fast; 0 stands for the full resolution, which a small or
/// slightly blurred code needs.
const SCAN_SIDES: [u32; 2] = [1200, 0];

/// What Signal Desktop and the other apps put into their linking QR code.
const LINK_SCHEME: &str = "sgnl://linkdevice";

/// Looks for a QR code in the photo at `path`. Emits "qrScanned" {text} for a
/// Signal linking code, "qrNone" otherwise. The photo is removed.
pub async fn scan(shared: &Shared, path: &str) {
    let path = PathBuf::from(path);
    let found = tokio::task::spawn_blocking(move || {
        let text = read_qr(&path);
        let _ = std::fs::remove_file(&path);
        text
    })
    .await
    .ok()
    .flatten();
    match found {
        Some(text) if text.starts_with(LINK_SCHEME) => {
            shared.sink.emit(json!({ "ev": "qrScanned", "text": text }))
        }
        Some(text) => {
            eprintln!("utlangis-core: QR code is not a linking code: {:.24}", text);
            shared.sink.emit(json!({ "ev": "qrNone" }))
        }
        None => shared.sink.emit(json!({ "ev": "qrNone" })),
    }
}

fn read_qr(path: &Path) -> Option<String> {
    let photo = match image::open(path) {
        Ok(photo) => photo,
        Err(error) => {
            eprintln!("utlangis-core: QR photo {} not readable: {}", path.display(), error);
            return None;
        }
    };
    let (width, height) = (photo.width(), photo.height());
    let side = (width.min(height) as f32 * SCAN_CROP) as u32;
    let cropped = photo.crop_imm((width - side) / 2, (height - side) / 2, side, side);
    for limit in SCAN_SIDES {
        let luma = if limit != 0 && side > limit {
            cropped.thumbnail(limit, limit).to_luma8()
        } else {
            cropped.to_luma8()
        };
        if let Some(text) = decode(luma) {
            return Some(text);
        }
    }
    eprintln!("utlangis-core: no QR code found in the {}x{} photo", width, height);
    None
}

/// ZXing's decoder (rxing) copes best with blurred and tilted codes; rqrr
/// is tried as well because it sometimes reads what ZXing misses.
fn decode(luma: image::GrayImage) -> Option<String> {
    let (width, height) = luma.dimensions();
    if let Ok(result) = rxing::helpers::detect_in_luma(
        luma.as_raw().clone(),
        width,
        height,
        Some(rxing::BarcodeFormat::QR_CODE),
    ) {
        return Some(result.getText().to_string());
    }
    let mut prepared = rqrr::PreparedImage::prepare(luma);
    prepared
        .detect_grids()
        .into_iter()
        .find_map(|grid| grid.decode().ok().map(|(_, text)| text))
}

pub async fn link(manager: &mut SignalManager, shared: &Shared, address: &str) {
    let url = match Url::parse(address) {
        Ok(url) if address.starts_with(LINK_SCHEME) => url,
        _ => return shared.sink.error_kind("linkDevice", "notLinkCode", "not a linking code"),
    };
    if let Err(error) = manager.link_secondary(url).await {
        return shared.sink.error("linkDevice", error);
    }
    shared.sink.emit(json!({ "ev": "deviceLinked" }));
    list(manager, shared).await;
}

/// Emits "devices" {devices: [{id, name, lastSeen, self}]}.
pub async fn list(manager: &mut SignalManager, shared: &Shared) {
    let devices = match manager.devices().await {
        Ok(devices) => devices,
        Err(error) => return shared.sink.error("devices", error),
    };
    let own = u32::from(manager.device_id());
    let rows: Vec<_> = devices
        .iter()
        .map(|device| {
            let id = u32::from(device.id);
            json!({ "id": id, "name": device.name.clone().unwrap_or_default(),
                    "lastSeen": device.last_seen.timestamp_millis(), "self": id == own })
        })
        .collect();
    shared.sink.emit(json!({ "ev": "devices", "devices": rows }));
}

pub async fn unlink(manager: &mut SignalManager, shared: &Shared, id: u32) {
    if let Err(error) = manager.unlink_secondary(id).await {
        return shared.sink.error("unlinkDevice", error);
    }
    list(manager, shared).await;
}
