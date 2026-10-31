// Conversation list for the chats page, newest first, as the backend sends
// it in "threads" events.

#ifndef THREADLISTMODEL_H
#define THREADLISTMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QVector>

class ThreadListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        ThreadRole = Qt::UserRole + 1,
        TitleRole,
        LastTextRole,
        LastTsRole,
        UnreadRole,
    };

    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void reset(const QJsonArray &threads);
    QString titleOf(const QString &thread) const;

private:
    struct Entry {
        QString thread;
        QString title;
        QString lastText;
        qint64 lastTs = 0;
        int unread = 0;
    };
    QVector<Entry> m_entries;
};

#endif
