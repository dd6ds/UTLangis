//! Attachments on the phone. Each one is stored as
//! `<attachments dir>/<message ts>_<index>.<ext>`, so the history can find the
//! files of a message again without a separate table.

use std::path::{Path, PathBuf};

use presage::libsignal_service::sender::AttachmentSpec;
use presage::proto::AttachmentPointer;

use crate::convert::MessageView;
use crate::events::StoredFile;
use crate::titles::SignalManager;

const FALLBACK_TYPE: &str = "application/octet-stream";

fn content_type_of(pointer: &AttachmentPointer) -> String {
    pointer.content_type.clone().unwrap_or_else(|| FALLBACK_TYPE.to_owned())
}

fn stored_path(dir: &Path, ts: u64, index: usize, content_type: &str) -> PathBuf {
    let ext = mime_guess::get_mime_extensions_str(content_type)
        .and_then(|exts| exts.first())
        .copied()
        .unwrap_or("bin");
    dir.join(format!("{ts}_{index}.{ext}"))
}

fn stored_file(path: &Path, content_type: String) -> StoredFile {
    StoredFile { path: path.to_string_lossy().into_owned(), content_type }
}

/// Fetches and decrypts the attachments of a received message.
pub async fn download(manager: &SignalManager, dir: &Path, view: &MessageView) -> Vec<StoredFile> {
    let mut files = Vec::new();
    for (index, pointer) in view.attachments.iter().enumerate() {
        let content_type = content_type_of(pointer);
        let path = stored_path(dir, view.ts, index, &content_type);
        let data = match manager.get_attachment(pointer).await {
            Ok(data) => data,
            Err(error) => {
                tracing::warn!(%error, "attachment download failed");
                continue;
            }
        };
        match std::fs::write(&path, data) {
            Ok(()) => files.push(stored_file(&path, content_type)),
            Err(error) => tracing::warn!(%error, "could not save attachment"),
        }
    }
    files
}

/// The attachments of a stored message that are on the phone.
pub fn existing(dir: &Path, view: &MessageView) -> Vec<StoredFile> {
    view.attachments
        .iter()
        .enumerate()
        .filter_map(|(index, pointer)| {
            let content_type = content_type_of(pointer);
            let path = stored_path(dir, view.ts, index, &content_type);
            path.exists().then(|| stored_file(&path, content_type))
        })
        .collect()
}

/// Reads the files to send. Files that cannot be read are reported in the
/// returned error instead of being skipped silently.
pub fn read_for_upload(paths: &[String]) -> Result<Vec<(AttachmentSpec, Vec<u8>)>, String> {
    paths
        .iter()
        .map(|path| {
            let data = std::fs::read(path).map_err(|e| format!("{path}: {e}"))?;
            let content_type = mime_guess::from_path(path)
                .first_raw()
                .unwrap_or(FALLBACK_TYPE)
                .to_owned();
            let spec = AttachmentSpec {
                content_type,
                length: data.len(),
                file_name: Path::new(path).file_name().map(|n| n.to_string_lossy().into_owned()),
                preview: None,
                voice_note: None,
                borderless: None,
                width: None,
                height: None,
                caption: None,
                blur_hash: None,
            };
            Ok((spec, data))
        })
        .collect()
}

/// Stores our copies of sent files (content type and bytes) under the
/// message's timestamp, so they show up in the history like received ones.
pub fn keep_sent(dir: &Path, ts: u64, copies: &[(String, Vec<u8>)]) -> Vec<StoredFile> {
    copies
        .iter()
        .enumerate()
        .filter_map(|(index, (content_type, data))| {
            let path = stored_path(dir, ts, index, content_type);
            std::fs::write(&path, data).ok()?;
            Some(stored_file(&path, content_type.clone()))
        })
        .collect()
}
