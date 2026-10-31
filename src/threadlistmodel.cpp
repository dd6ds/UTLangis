// Conversation list model, see threadlistmodel.h.

#include "threadlistmodel.h"

#include <QJsonObject>

int ThreadListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant ThreadListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};
    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case ThreadRole: return entry.thread;
    case TitleRole: return entry.title;
    case LastTextRole: return entry.lastText;
    case LastTsRole: return entry.lastTs;
    case UnreadRole: return entry.unread;
    default: return {};
    }
}

QHash<int, QByteArray> ThreadListModel::roleNames() const
{
    return {{ThreadRole, "thread"},
            {TitleRole, "title"},
            {LastTextRole, "lastText"},
            {LastTsRole, "lastTs"},
            {UnreadRole, "unread"}};
}

void ThreadListModel::reset(const QJsonArray &threads)
{
    beginResetModel();
    m_entries.clear();
    for (const QJsonValue &value : threads) {
        const QJsonObject object = value.toObject();
        m_entries.append({object.value(QStringLiteral("thread")).toString(),
                          object.value(QStringLiteral("title")).toString(),
                          object.value(QStringLiteral("lastText")).toString(),
                          static_cast<qint64>(object.value(QStringLiteral("lastTs")).toDouble()),
                          object.value(QStringLiteral("unread")).toInt()});
    }
    endResetModel();
}

QString ThreadListModel::titleOf(const QString &thread) const
{
    for (const Entry &entry : m_entries) {
        if (entry.thread == thread)
            return entry.title;
    }
    return {};
}
