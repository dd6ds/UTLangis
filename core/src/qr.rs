//! QR code of the linking address, written as a greyscale PGM image that Qt
//! reads without extra plugins.

use std::path::Path;

use qrcode::{Color, QrCode};

/// Pixels per QR module, and the white border (in modules) scanners need.
const SCALE: usize = 8;
const QUIET_ZONE: usize = 4;

pub fn write_pgm(text: &str, path: &Path) -> Result<(), String> {
    let code = QrCode::new(text.as_bytes()).map_err(|e| e.to_string())?;
    let modules = code.width();
    let colors = code.to_colors();
    let size = (modules + 2 * QUIET_ZONE) * SCALE;

    let mut image = format!("P5\n{size} {size}\n255\n").into_bytes();
    for y in 0..size {
        for x in 0..size {
            let (mx, my) = (x / SCALE, y / SCALE);
            let dark = mx >= QUIET_ZONE
                && my >= QUIET_ZONE
                && mx < modules + QUIET_ZONE
                && my < modules + QUIET_ZONE
                && colors[(my - QUIET_ZONE) * modules + (mx - QUIET_ZONE)] == Color::Dark;
            image.push(if dark { 0 } else { 255 });
        }
    }
    std::fs::write(path, image).map_err(|e| e.to_string())
}
