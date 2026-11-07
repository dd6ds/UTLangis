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
    // Linked as an additional device of an account (not its primary device).
    Q_PROPERTY(bool linked READ linked NOTIFY stateChanged)
    // QR code image to scan while linking ("" until Signal sent the address).
    Q_PROPERTY(QString linkQrPath READ linkQrPath NOTIFY stateChanged)
    // A registration step or a send is in progress.
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString currentThread READ currentThread NOTIFY currentThreadChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentThreadChanged)
    // Tell senders when their messages were read (Settings).
    Q_PROPERTY(bool sendReadReceipts READ sendReadReceipts WRITE setSendReadReceipts
               NOTIFY sendReadReceiptsChanged)
    // Other devices of the account: [{ id, name, lastSeen, self }], filled
    // by refreshDevices().
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(ThreadListModel *threads READ threads CONSTANT)
    Q_PROPERTY(MessageListModel *messages READ messages CONSTANT)

public:
    SignalClient(const QString &dataDir, Notifier *notifier, QObject *parent = nullptr);
    ~SignalClient() override;

    QString state() const { return m_state; }
    QString phone() const { return m_phone; }
    bool linked() const { return m_linked; }
    QString linkQrPath() const { return m_linkQrPath; }
    bool busy() const { return m_busy; }
    QString currentThread() const { return m_currentThread; }
    QString currentTitle() const;
    bool sendReadReceipts() const { return m_sendReadReceipts; }
    QVariantList devices() const { return m_devices; }
    void setSendReadReceipts(bool send);
    ThreadListModel *threads() { return &m_threads; }
    MessageListModel *messages() { return &m_messages; }

    Q_INVOKABLE void registerNumber(const QString &phone, const QString &captcha, bool voice);
    Q_INVOKABLE void confirmCode(const QString &code);
    // Links as an additional device of an existing account (QR code).
    Q_INVOKABLE void linkDevice();
    Q_INVOKABLE void cancelLink();
    Q_INVOKABLE void setProfileName(const QString &name);
    Q_INVOKABLE void openThread(const QString &thread);
    Q_INVOKABLE void closeThread();
    // quote: {ts, author, text, name} of the message this one replies to, or
    // an empty map.
    Q_INVOKABLE void sendMessage(const QString &text, const QStringList &attachmentUrls,
                                 const QVariantMap &quote);
    // Sends a recording from VoiceNotes as a voice message.
    Q_INVOKABLE void sendVoiceNote(const QString &url);
    // Reads a contact picked in the Contacts app (vCard file URL from the
    // Content Hub) as { name, numbers: [..] }.
    Q_INVOKABLE QVariantMap readContactCard(const QString &url) const;
    // Changes the text of an own message of the open chat (ts = its sent
    // time).
    Q_INVOKABLE void editMessage(qint64 ts, const QString &text);
    // Deletes a message of the open chat (ts = its sent time); `everyone`
    // also asks the other side(s) to delete it.
    Q_INVOKABLE void deleteMessage(qint64 ts, bool everyone);
    // Reacts to a message of the open chat (author: its sender's service id,
    // "" for own messages); remove takes the own reaction back.
    Q_INVOKABLE void react(qint64 ts, const QString &author, const QString &emoji, bool remove);
    // Own name for the open one-to-one chat; "" = the Signal profile name.
    Q_INVOKABLE void renameThread(const QString &name);
    // name: from the Contacts app, "" for a typed number.
    Q_INVOKABLE void startChat(const QString &phone, const QString &name);
    // Where the QR scanner stores a camera photo for scanQr().
    Q_INVOKABLE QString qrPhotoPath() const;
    // Looks for a Signal linking QR code in a camera photo: qrScanned or
    // qrNotFound follows. The photo is removed.
    Q_INVOKABLE void scanQr(const QString &path);
    // Links another device (Signal Desktop) by the address of its QR code.
    Q_INVOKABLE void linkDevice(const QString &url);
    Q_INVOKABLE void refreshDevices();
    Q_INVOKABLE void unlinkDevice(int id);
    // Calls (CallEngine): signalling out, TURN servers, call log.
    void sendCallSignal(const QJsonObject &signal);
    void requestTurnServers();
    void callAnswered(const QString &callId);
    void callStarted(const QString &thread, bool video);
    // Joins the phone number chat `from` into the person's chat `to`.
    Q_INVOKABLE void mergeChats(const QString &from, const QString &to);
    // Declines the ringing call `callId` (from incomingCall).
    Q_INVOKABLE void declineCall(const QString &callId);
    // Called when the app comes back from being suspended.
    void reconnect();

signals:
    void stateChanged();
    void busyChanged();
    void currentThreadChanged();
    void sendReadReceiptsChanged();
    void devicesChanged();
    void qrScanned(const QString &text);
    void qrNotFound();
    void deviceLinked();
    // Someone calls us; answering is not possible yet.
    void incomingCall(const QString &callId, const QString &thread, const QString &title,
                      bool video);
    // The call `callId` stopped ringing (hung up, answered elsewhere, ...).
    void callEnded(const QString &callId);
    // A received call signalling message for RingRTC (see core calls.rs).
    void callSignal(const QJsonObject &signal);
    void turnServersReceived(const QJsonArray &servers, int localDeviceId);
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
    void markRead(const QString &thread);

    ThreadListModel m_threads;
    MessageListModel m_messages;
    Notifier *m_notifier;
    QString m_state = QStringLiteral("starting");
    QString m_phone;
    QString m_linkQrPath;
    bool m_linked = false;
    QString m_currentThread;
    bool m_busy = false;
    bool m_started = false;
    bool m_sendReadReceipts = true;
    QVariantList m_devices;
    QString m_dataDir;
};

#endif
