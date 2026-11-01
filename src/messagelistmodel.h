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
        // Author's service id ("" for own messages), for replies.
        SenderRole,
        // The message replies to another one, shown as a quote above it.
        HasQuoteRole,
        QuoteTextRole,
        QuoteAuthorRole,
        QuoteOwnRole,
        // Own messages: 0 unknown, 1 sent, 2 delivered, 3 read.
        StatusRole,
        // Reactions as { reactor: emoji }; "me" is our own.
        ReactionsRole,
    };

    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void reset(const QJsonArray &messages);
    void append(const QJsonObject &message);
    // Removes the message sent at `ts` (Signal's message id), if shown.
    void remove(qint64 ts);
    // Raises the delivery state of the own messages sent at `timestamps`.
    void setStatus(const QJsonArray &timestamps, int status);
    // Sets or (remove) clears one person's reaction to the message `target`.
    void setReaction(qint64 target, const QString &reactor, const QString &emoji, bool remove);
    void clear();

private:
    struct Entry {
        bool outgoing = false;
        QString text;
        QString senderName;
        qint64 ts = 0;
        QVariantList attachments;
        QString sender;
        bool hasQuote = false;
        QString quoteText;
        QString quoteAuthor;
        bool quoteOwn = false;
        int status = 0;
        QVariantMap reactions;
    };
    static Entry fromJson(const QJsonObject &message);

    QVector<Entry> m_entries;
};

#endif
