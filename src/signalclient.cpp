// Command and event handling for the Rust backend, see signalclient.h and
// the format description at the top of core/src/lib.rs.

#include "signalclient.h"

#include <QDebug>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QUrl>

#include "ubsignal_core.h"

SignalClient::SignalClient(const QString &dataDir, QObject *parent) : QObject(parent)
{
    m_started = ubsignal_start(dataDir.toUtf8().constData(), &SignalClient::eventCallback, this);
    if (!m_started)
        qWarning() << "SignalClient: backend did not start, data dir" << dataDir;
}

SignalClient::~SignalClient()
{
    // Waits for the backend thread, so no callback can arrive afterwards.
    if (m_started)
        ubsignal_stop();
}

// Runs on the backend thread: hand the event over to the GUI thread.
void SignalClient::eventCallback(void *context, const char *json)
{
    auto *client = static_cast<SignalClient *>(context);
    QMetaObject::invokeMethod(client, "onEvent", Qt::QueuedConnection,
                              Q_ARG(QByteArray, QByteArray(json)));
}

void SignalClient::command(const QJsonObject &command)
{
    ubsignal_command(QJsonDocument(command).toJson(QJsonDocument::Compact).constData());
}

void SignalClient::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

QString SignalClient::currentTitle() const
{
    return m_threads.titleOf(m_currentThread);
}

void SignalClient::registerNumber(const QString &phone, const QString &captcha, bool voice)
{
    qDebug() << "SignalClient: requesting a code, captcha length" << captcha.size();
    setBusy(true);
    command({{QStringLiteral("cmd"), QStringLiteral("register")},
             {QStringLiteral("phone"), phone},
             {QStringLiteral("captcha"), captcha},
             {QStringLiteral("voice"), voice}});
}

void SignalClient::confirmCode(const QString &code)
{
    setBusy(true);
    command({{QStringLiteral("cmd"), QStringLiteral("confirm")},
             {QStringLiteral("code"), code}});
}

void SignalClient::setProfileName(const QString &name)
{
    command({{QStringLiteral("cmd"), QStringLiteral("setProfile")},
             {QStringLiteral("name"), name}});
}

void SignalClient::openThread(const QString &thread)
{
    m_currentThread = thread;
    m_messages.clear();
    emit currentThreadChanged();
    command({{QStringLiteral("cmd"), QStringLiteral("history")},
             {QStringLiteral("thread"), thread}});
    command({{QStringLiteral("cmd"), QStringLiteral("markRead")},
             {QStringLiteral("thread"), thread}});
}

void SignalClient::closeThread()
{
    m_currentThread.clear();
    m_messages.clear();
    emit currentThreadChanged();
}

void SignalClient::sendMessage(const QString &text, const QStringList &attachmentUrls)
{
    QJsonArray paths;
    for (const QString &url : attachmentUrls)
        paths.append(QUrl(url).toLocalFile());
    setBusy(true);
    command({{QStringLiteral("cmd"), QStringLiteral("send")},
             {QStringLiteral("thread"), m_currentThread},
             {QStringLiteral("text"), text},
             {QStringLiteral("attachments"), paths}});
}

void SignalClient::startChat(const QString &phone, const QString &name)
{
    qDebug() << "SignalClient: looking up a number for a new chat";
    setBusy(true);
    command({{QStringLiteral("cmd"), QStringLiteral("resolve")},
             {QStringLiteral("phone"), phone},
             {QStringLiteral("name"), name}});
}

void SignalClient::reconnect()
{
    if (m_state != QLatin1String("offline") && m_state != QLatin1String("online"))
        return;
    command({{QStringLiteral("cmd"), QStringLiteral("reconnect")}});
    if (!m_currentThread.isEmpty())
        command({{QStringLiteral("cmd"), QStringLiteral("markRead")},
                 {QStringLiteral("thread"), m_currentThread}});
}

bool SignalClient::isShowing(const QString &thread) const
{
    return thread == m_currentThread && qApp->applicationState() == Qt::ApplicationActive;
}

void SignalClient::onEvent(const QByteArray &json)
{
    const QJsonObject event = QJsonDocument::fromJson(json).object();
    const QString name = event.value(QStringLiteral("ev")).toString();
    const QString thread = event.value(QStringLiteral("thread")).toString();
    if (name == QLatin1String("state")) {
        onState(event);
    } else if (name == QLatin1String("threads")) {
        m_threads.reset(event.value(QStringLiteral("threads")).toArray());
        // The title of the open chat may just have become known.
        emit currentThreadChanged();
    } else if (name == QLatin1String("history")) {
        if (thread == m_currentThread)
            m_messages.reset(event.value(QStringLiteral("messages")).toArray());
    } else if (name == QLatin1String("message")) {
        onIncoming(event);
    } else if (name == QLatin1String("sent")) {
        setBusy(false);
        if (thread == m_currentThread)
            m_messages.append(event);
    } else if (name == QLatin1String("resolved")) {
        setBusy(false);
        emit chatStarted(thread);
    } else if (name == QLatin1String("profileSet")) {
        emit profileSet();
    } else if (name == QLatin1String("error")) {
        onError(event);
    }
}

void SignalClient::onState(const QJsonObject &event)
{
    m_state = event.value(QStringLiteral("state")).toString();
    m_phone = event.value(QStringLiteral("phone")).toString();
    // A state change ends a registration step; online/offline changes do
    // not affect a send that is in progress.
    if (m_state == QLatin1String("unregistered") || m_state == QLatin1String("awaitingCode"))
        setBusy(false);
    qDebug() << "SignalClient: state" << m_state;
    emit stateChanged();
}

void SignalClient::onIncoming(const QJsonObject &event)
{
    const QString thread = event.value(QStringLiteral("thread")).toString();
    if (thread == m_currentThread)
        m_messages.append(event);
    if (isShowing(thread)) {
        command({{QStringLiteral("cmd"), QStringLiteral("markRead")},
                 {QStringLiteral("thread"), thread}});
        return;
    }
    if (!event.value(QStringLiteral("outgoing")).toBool())
        m_notifier.notify(event.value(QStringLiteral("title")).toString(),
                          event.value(QStringLiteral("senderName")).toString(),
                          event.value(QStringLiteral("text")).toString());
}

void SignalClient::onError(const QJsonObject &event)
{
    qWarning() << "SignalClient: error" << event.value(QStringLiteral("action")).toString()
               << event.value(QStringLiteral("message")).toString();
    setBusy(false);
    emit errorOccurred(event.value(QStringLiteral("action")).toString(),
                       event.value(QStringLiteral("kind")).toString(),
                       event.value(QStringLiteral("message")).toString());
}
