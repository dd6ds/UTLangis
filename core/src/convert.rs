//! Turns Signal message contents into the plain message rows the app shows.
//! Receipts, typing notices, calls and stories are not shown and yield None.

use presage::libsignal_service::content::{Content, ContentBody, DataMessage};
use presage::libsignal_service::protocol::ServiceId;
use presage::proto::sync_message::{Content as SyncContent, Sent};
use presage::proto::{AttachmentPointer, EditMessage, SyncMessage};
use presage::store::Thread;

pub struct MessageView {
    pub thread: Thread,
    pub sender: ServiceId,
    pub outgoing: bool,
    pub text: String,
    /// Sent time in milliseconds since the epoch (Signal's message id).
    pub ts: u64,
    pub attachments: Vec<AttachmentPointer>,
}

/// `own` is our account id: messages sent from this phone are stored with it
/// as sender, messages sent from a linked device arrive as sync messages.
pub fn view(content: &Content, own: &ServiceId) -> Option<MessageView> {
    let (data, outgoing) = data_message(&content.body)?;
    let text = message_text(data)?;
    let thread = Thread::try_from(content).ok()?;
    Some(MessageView {
        thread,
        sender: content.metadata.sender,
        outgoing: outgoing || content.metadata.sender == *own,
        text,
        ts: data.timestamp.unwrap_or_else(|| content.metadata.client_timestamp
            .timestamp_millis() as u64),
        attachments: data.attachments.clone(),
    })
}

/// The message a "delete for everyone" request removes: its thread and sent
/// timestamp. presage has already blanked that message in the store.
pub fn deletion(content: &Content) -> Option<(Thread, u64)> {
    let (data, _) = data_message(&content.body)?;
    let ts = data.delete.as_ref()?.target_sent_timestamp?;
    Some((Thread::try_from(content).ok()?, ts))
}

fn data_message(body: &ContentBody) -> Option<(&DataMessage, bool)> {
    match body {
        ContentBody::DataMessage(data) => Some((data, false)),
        ContentBody::EditMessage(EditMessage { data_message: Some(data), .. }) => {
            Some((data, false))
        }
        ContentBody::SynchronizeMessage(SyncMessage {
            content: Some(SyncContent::Sent(Sent { message: Some(data), .. })),
            ..
        }) => Some((data, true)),
        ContentBody::SynchronizeMessage(SyncMessage {
            content:
                Some(SyncContent::Sent(Sent {
                    edit_message: Some(EditMessage { data_message: Some(data), .. }),
                    ..
                })),
            ..
        }) => Some((data, true)),
        _ => None,
    }
}

/// The text to show, or None for data messages that carry nothing visible
/// (profile key updates, group changes without text, deletions).
fn message_text(data: &DataMessage) -> Option<String> {
    let body = data.body.clone().unwrap_or_default();
    if body.is_empty() && data.attachments.is_empty() {
        return None;
    }
    Some(body)
}
