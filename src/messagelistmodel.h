// Messages of the open conversation, oldest first: the history sent by the
// backend plus messages that arrive or are sent while it is open.

#ifndef MESSAGELISTMODEL_H
#define MESSAGELISTMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantList>
#include <QVector>

class MessageListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        OutgoingRole = Qt::UserRole + 1,
        TextRole,
        SenderNameRole,
        TsRole,
        // List of {path, type} maps.
        AttachmentsRole,
    };

    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void reset(const QJsonArray &messages);
    void append(const QJsonObject &message);
    // Removes the message sent at `ts` (Signal's message id), if shown.
    void remove(qint64 ts);
    void clear();

private:
    struct Entry {
        bool outgoing = false;
        QString text;
        QString senderName;
        qint64 ts = 0;
        QVariantList attachments;
    };
    static Entry fromJson(const QJsonObject &message);

    QVector<Entry> m_entries;
};

#endif
