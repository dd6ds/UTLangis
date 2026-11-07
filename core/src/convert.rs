//! Turns Signal message contents into the plain message rows the app shows.
//! Receipts, typing notices, calls and stories are not shown and yield None.

use presage::libsignal_service::content::{Content, ContentBody, DataMessage};
use presage::libsignal_service::protocol::ServiceId;
use presage::proto::sync_message::{Content as SyncContent, Sent};
use presage::proto::{AttachmentPointer, SyncMessage};
use presage::store::Thread;

pub struct MessageView {
    pub thread: Thread,
    pub sender: ServiceId,
    pub outgoing: bool,
    pub text: String,
    /// Sent time in milliseconds since the epoch (Signal's message id).
    pub ts: u64,
    pub attachments: Vec<AttachmentPointer>,
    pub quote: Option<QuoteView>,
}

/// The message a reply refers to, as the reply carries it.
pub struct QuoteView {
    pub author: Option<ServiceId>,
    /// Quoted one of our own messages.
    pub own: bool,
    /// "" when the quoted message only had attachments.
    pub text: String,
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
        quote: data.quote.as_ref().map(|quote| {
            let author =
                quote.author_aci.as_deref().and_then(ServiceId::parse_from_service_id_string);
            QuoteView {
                own: author.as_ref() == Some(own),
                author,
                text: quote.text.clone().unwrap_or_default(),
            }
        }),
    })
}

/// A reaction to an earlier message of a conversation.
pub struct ReactionView {
    pub thread: Thread,
    /// Sent timestamp of the message reacted to.
    pub target: u64,
    /// "me" for our own reactions, otherwise the reactor's service id.
    pub reactor: String,
    pub emoji: String,
    /// The reactor took their reaction back.
    pub remove: bool,
}

pub fn reaction(content: &Content, own: &ServiceId) -> Option<ReactionView> {
    let (data, outgoing) = data_message(&content.body)?;
    let reaction = data.reaction.as_ref()?;
    let mine = outgoing || content.metadata.sender == *own;
    Some(ReactionView {
        thread: Thread::try_from(content).ok()?,
        target: reaction.target_sent_timestamp?,
        reactor: if mine { ME.to_owned() } else { content.metadata.sender.service_id_string() },
        emoji: reaction.emoji.clone().unwrap_or_default(),
        remove: reaction.remove.unwrap_or(false),
    })
}

/// Reactor name for our own reactions in events and history rows.
pub const ME: &str = "me";

/// The message a "delete for everyone" request removes: its thread and sent
/// timestamp. presage has already blanked that message in the store.
pub fn deletion(content: &Content) -> Option<(Thread, u64)> {
    let (data, _) = data_message(&content.body)?;
    let ts = data.delete.as_ref()?.target_sent_timestamp?;
    Some((Thread::try_from(content).ok()?, ts))
}

/// A changed version of an earlier message ("edit"). Signal keeps the
/// original's sent timestamp as the message's id; the edit carries the new
/// text and its own timestamp.
pub struct EditView {
    pub thread: Thread,
    /// Sent timestamp of the message that was changed.
    pub target: u64,
    pub text: String,
    /// When the change was made; the latest change of a message wins.
    pub ts: u64,
}

pub fn edit(content: &Content) -> Option<EditView> {
    let edit = match &content.body {
        ContentBody::EditMessage(edit) => edit,
        ContentBody::SynchronizeMessage(SyncMessage {
            content: Some(SyncContent::Sent(Sent { edit_message: Some(edit), .. })),
            ..
        }) => edit,
        _ => return None,
    };
    let data = edit.data_message.as_ref()?;
    Some(EditView {
        thread: Thread::try_from(content).ok()?,
        target: edit.target_sent_timestamp?,
        text: data.body.clone().unwrap_or_default(),
        ts: data.timestamp.unwrap_or_default(),
    })
}

/// The message itself (text, attachments, quote) of stored message contents.
pub fn data(content: &Content) -> Option<&DataMessage> {
    data_message(&content.body).map(|(data, _)| data)
}

/// The data message of a received message or of one sent from another of our
/// devices (sync), and whether it is our own. Edits are left out: they change
/// an earlier message instead of being one (see `edit`).
fn data_message(body: &ContentBody) -> Option<(&DataMessage, bool)> {
    match body {
        ContentBody::DataMessage(data) => Some((data, false)),
        ContentBody::SynchronizeMessage(SyncMessage {
            content: Some(SyncContent::Sent(Sent { message: Some(data), .. })),
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
