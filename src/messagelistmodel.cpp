// Message list model, see messagelistmodel.h.

#include "messagelistmodel.h"

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
    default: return {};
    }
}

QHash<int, QByteArray> MessageListModel::roleNames() const
{
    return {{OutgoingRole, "outgoing"},
            {TextRole, "text"},
            {SenderNameRole, "senderName"},
            {TsRole, "ts"},
            {AttachmentsRole, "attachments"}};
}

MessageListModel::Entry MessageListModel::fromJson(const QJsonObject &message)
{
    return {message.value(QStringLiteral("outgoing")).toBool(),
            message.value(QStringLiteral("text")).toString(),
            message.value(QStringLiteral("senderName")).toString(),
            static_cast<qint64>(message.value(QStringLiteral("ts")).toDouble()),
            message.value(QStringLiteral("attachments")).toArray().toVariantList()};
}

void MessageListModel::reset(const QJsonArray &messages)
{
    beginResetModel();
    m_entries.clear();
    for (const QJsonValue &value : messages)
        m_entries.append(fromJson(value.toObject()));
    endResetModel();
}

void MessageListModel::append(const QJsonObject &message)
{
    const Entry entry = fromJson(message);
    // A message can arrive twice when the history request and a live event
    // overlap; Signal identifies messages by their sent timestamp.
    for (const Entry &existing : m_entries) {
        if (existing.ts == entry.ts && existing.outgoing == entry.outgoing)
            return;
    }
    beginInsertRows(QModelIndex(), m_entries.size(), m_entries.size());
    m_entries.append(entry);
    endInsertRows();
}

void MessageListModel::clear()
{
    beginResetModel();
    m_entries.clear();
    endResetModel();
}
