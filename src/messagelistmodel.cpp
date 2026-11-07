// Message list model, see messagelistmodel.h.

#include "messagelistmodel.h"

#include <algorithm>

int MessageListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant MessageListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};
    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case OutgoingRole: return entry.outgoing;
    case TextRole: return entry.text;
    case SenderNameRole: return entry.senderName;
    case TsRole: return entry.ts;
    case AttachmentsRole: return entry.attachments;
    case SenderRole: return entry.sender;
    case HasQuoteRole: return entry.hasQuote;
    case QuoteTextRole: return entry.quoteText;
    case QuoteAuthorRole: return entry.quoteAuthor;
    case QuoteOwnRole: return entry.quoteOwn;
    case StatusRole: return entry.status;
    case ReactionsRole: return entry.reactions;
    case EditedRole: return entry.edited;
    case CallRole: return entry.call;
    case VideoRole: return entry.video;
    default: return {};
    }
}

QHash<int, QByteArray> MessageListModel::roleNames() const
{
    return {{OutgoingRole, "outgoing"},
            {TextRole, "text"},
            {SenderNameRole, "senderName"},
            {TsRole, "ts"},
            {AttachmentsRole, "attachments"},
            {SenderRole, "sender"},
            {HasQuoteRole, "hasQuote"},
            {QuoteTextRole, "quoteText"},
            {QuoteAuthorRole, "quoteAuthor"},
            {QuoteOwnRole, "quoteOwn"},
            {StatusRole, "status"},
            {ReactionsRole, "reactions"},
            {EditedRole, "edited"},
            {CallRole, "call"},
            {VideoRole, "video"}};
}

MessageListModel::Entry MessageListModel::fromJson(const QJsonObject &message)
{
    return {message.value(QStringLiteral("outgoing")).toBool(),
            message.value(QStringLiteral("text")).toString(),
            message.value(QStringLiteral("senderName")).toString(),
            static_cast<qint64>(message.value(QStringLiteral("ts")).toDouble()),
            message.value(QStringLiteral("attachments")).toArray().toVariantList(),
            message.value(QStringLiteral("sender")).toString(),
            message.value(QStringLiteral("hasQuote")).toBool(),
            message.value(QStringLiteral("quoteText")).toString(),
            message.value(QStringLiteral("quoteAuthor")).toString(),
            message.value(QStringLiteral("quoteOwn")).toBool(),
            message.value(QStringLiteral("status")).toInt(),
            message.value(QStringLiteral("reactions")).toObject().toVariantMap(),
            message.value(QStringLiteral("edited")).toBool(),
            message.value(QStringLiteral("call")).toString(),
            message.value(QStringLiteral("video")).toBool()};
}

qint64 MessageListModel::tsAt(int row) const
{
    return row >= 0 && row < m_entries.size() ? m_entries.at(row).ts : 0;
}

void MessageListModel::reset(const QJsonArray &messages)
{
    beginResetModel();
    m_entries.clear();
    for (const QJsonValue &value : messages)
        m_entries.append(fromJson(value.toObject()));
    // Oldest first, so the newest message is at the bottom of the chat.
    std::stable_sort(m_entries.begin(), m_entries.end(),
                     [](const Entry &a, const Entry &b) { return a.ts < b.ts; });
    endResetModel();
}

void MessageListModel::append(const QJsonObject &message)
{
    const Entry entry = fromJson(message);
    // A message can arrive twice when the history request and a live event
    // overlap; Signal identifies messages by their sent timestamp.
    for (const Entry &existing : m_entries) {
        if (existing.ts == entry.ts && existing.outgoing == entry.outgoing
                && existing.call == entry.call)
            return;
    }
    beginInsertRows(QModelIndex(), m_entries.size(), m_entries.size());
    m_entries.append(entry);
    endInsertRows();
}

void MessageListModel::remove(qint64 ts)
{
    for (int row = 0; row < m_entries.size(); ++row) {
        if (m_entries.at(row).ts == ts) {
            beginRemoveRows(QModelIndex(), row, row);
            m_entries.removeAt(row);
            endRemoveRows();
            return;
        }
    }
}

void MessageListModel::setStatus(const QJsonArray &timestamps, int status)
{
    for (const QJsonValue &value : timestamps) {
        const qint64 ts = static_cast<qint64>(value.toDouble());
        for (int row = 0; row < m_entries.size(); ++row) {
            Entry &entry = m_entries[row];
            if (entry.ts == ts && entry.outgoing && entry.status < status) {
                entry.status = status;
                const QModelIndex changed = index(row);
                emit dataChanged(changed, changed, {StatusRole});
            }
        }
    }
}

void MessageListModel::setReaction(qint64 target, const QString &reactor,
                                   const QString &emoji, bool remove)
{
    for (int row = 0; row < m_entries.size(); ++row) {
        Entry &entry = m_entries[row];
        if (entry.ts != target)
            continue;
        if (remove)
            entry.reactions.remove(reactor);
        else
            entry.reactions.insert(reactor, emoji);
        const QModelIndex changed = index(row);
        emit dataChanged(changed, changed, {ReactionsRole});
        return;
    }
}

void MessageListModel::setEdited(qint64 target, const QString &text)
{
    for (int row = 0; row < m_entries.size(); ++row) {
        Entry &entry = m_entries[row];
        if (entry.ts != target)
            continue;
        entry.text = text;
        entry.edited = true;
        const QModelIndex changed = index(row);
        emit dataChanged(changed, changed, {TextRole, EditedRole});
        return;
    }
}

void MessageListModel::clear()
{
    beginResetModel();
    m_entries.clear();
    endResetModel();
}
