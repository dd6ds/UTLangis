// Bridge between QML and the Rust Signal backend (core/). Turns QML calls
// into JSON commands and the backend's JSON events into properties, model
// updates and signals. Exposed to QML as "Signal".

#ifndef SIGNALCLIENT_H
#define SIGNALCLIENT_H

#include <QJsonObject>
#include <QObject>
#include <QStringList>

#include "messagelistmodel.h"
#include "notifier.h"
#include "threadlistmodel.h"

class SignalClient : public QObject
{
    Q_OBJECT
    // "starting", "unregistered", "awaitingCode", "offline", "online".
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString phone READ phone NOTIFY stateChanged)
    // A registration step or a send is in progress.
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString currentThread READ currentThread NOTIFY currentThreadChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentThreadChanged)
    Q_PROPERTY(ThreadListModel *threads READ threads CONSTANT)
    Q_PROPERTY(MessageListModel *messages READ messages CONSTANT)

public:
    explicit SignalClient(const QString &dataDir, QObject *parent = nullptr);
    ~SignalClient() override;

    QString state() const { return m_state; }
    QString phone() const { return m_phone; }
    bool busy() const { return m_busy; }
    QString currentThread() const { return m_currentThread; }
    QString currentTitle() const;
    ThreadListModel *threads() { return &m_threads; }
    MessageListModel *messages() { return &m_messages; }

    Q_INVOKABLE void registerNumber(const QString &phone, const QString &captcha, bool voice);
    Q_INVOKABLE void confirmCode(const QString &code);
    Q_INVOKABLE void setProfileName(const QString &name);
    Q_INVOKABLE void openThread(const QString &thread);
    Q_INVOKABLE void closeThread();
    Q_INVOKABLE void sendMessage(const QString &text, const QStringList &attachmentUrls);
    // Sends a recording from VoiceNotes as a voice message.
    Q_INVOKABLE void sendVoiceNote(const QString &url);
    // name: from the address book, "" for a typed number.
    // Deletes a message of the open chat (ts = its sent time); `everyone`
    // also asks the other side(s) to delete it.
    Q_INVOKABLE void deleteMessage(qint64 ts, bool everyone);
    Q_INVOKABLE void startChat(const QString &phone, const QString &name);
    // Called when the app comes back from being suspended.
    void reconnect();

signals:
    void stateChanged();
    void busyChanged();
    void currentThreadChanged();
    // action: the command that failed; kind: short code QML translates.
    void errorOccurred(const QString &action, const QString &kind, const QString &message);
    void chatStarted(const QString &thread);
    void profileSet();

private:
    Q_INVOKABLE void onEvent(const QByteArray &json);
    static void eventCallback(void *context, const char *json);

    void command(const QJsonObject &command);
    void setBusy(bool busy);
    void onState(const QJsonObject &event);
    void onIncoming(const QJsonObject &event);
    void onError(const QJsonObject &event);
    bool isShowing(const QString &thread) const;

    ThreadListModel m_threads;
    MessageListModel m_messages;
    Notifier m_notifier;
    QString m_state = QStringLiteral("starting");
    QString m_phone;
    QString m_currentThread;
    bool m_busy = false;
    bool m_started = false;
};

#endif
