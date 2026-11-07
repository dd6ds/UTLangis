#include "callengine.h"

#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QJsonDocument>
#include <QRandomGenerator>

#include "signalclient.h"

namespace {
const QString kIncoming = QStringLiteral("incoming");
const QString kEnded = QStringLiteral("ended");
// How long "ended" stays on the call screen.
const int kEndedShownMs = 2000;
}

CallEngine::CallEngine(SignalClient *client, QObject *parent)
    : QObject(parent), m_client(client)
{
    m_library.setFileName(QCoreApplication::applicationDirPath()
                          + QStringLiteral("/lib/libutlangis_calls.so"));
    connect(client, &SignalClient::callSignal, this, &CallEngine::onSignal);
    connect(client, &SignalClient::turnServersReceived, this, &CallEngine::onTurnServers);
    connect(client, &SignalClient::incomingCall, this,
            [this](const QString &callId, const QString &thread, const QString &title, bool) {
                onIncomingCall(callId, thread, title);
            });
    connect(client, &SignalClient::callEnded, this, &CallEngine::onRingingEnded);
    m_audio.restoreAfterInterruptedCall();
    m_ticker.setInterval(1000);
    connect(&m_ticker, &QTimer::timeout, this, &CallEngine::tick);
}

void CallEngine::onIncomingCall(const QString &callId, const QString &thread,
                                const QString &title)
{
    if (callId == m_callId || m_thread.isEmpty()) {
        m_thread = thread;
        m_title = title;
    }
    // Rings unless we are in a call already.
    if (m_state.isEmpty() || m_state == kIncoming)
        m_audio.startRinging();
    emit changed();
}

// Stopped ringing: answered or declined elsewhere, or the caller gave up.
void CallEngine::onRingingEnded()
{
    if (m_state.isEmpty() || m_state == kIncoming) {
        m_audio.stopRinging();
        emit changed();
    }
}

CallEngine::~CallEngine()
{
    if (m_started && m_stop)
        m_stop();
}

bool CallEngine::load()
{
    if (m_tried)
        return m_started;
    m_tried = true;
    if (!m_library.load()) {
        qWarning() << "CallEngine: no call library:" << m_library.errorString();
        return false;
    }
    m_start = reinterpret_cast<StartFn>(m_library.resolve("ut_calls_start"));
    m_command = reinterpret_cast<CommandFn>(m_library.resolve("ut_calls_command"));
    m_stop = reinterpret_cast<StopFn>(m_library.resolve("ut_calls_stop"));
    m_pushFrame = reinterpret_cast<PushFrameFn>(m_library.resolve("ut_calls_push_frame"));
    auto setVideoCallback =
            reinterpret_cast<SetVideoCallbackFn>(m_library.resolve("ut_calls_set_video_callback"));
    if (setVideoCallback)
        setVideoCallback(&CallEngine::frameCallback, this);
    if (!m_start || !m_command || !m_stop) {
        qWarning() << "CallEngine: call library incomplete";
        return false;
    }
    m_started = m_start(&CallEngine::eventCallback, this);
    if (!m_started)
        qWarning() << "CallEngine: call library did not start";
    emit changed();
    return m_started;
}

bool CallEngine::available()
{
    // The library starts WebRTC and the audio devices, so it is loaded only
    // for the first call.
    return m_tried ? m_started : QFile::exists(m_library.fileName());
}

int CallEngine::seconds() const
{
    return m_state == QLatin1String("connected") && m_connected.isValid()
            ? static_cast<int>(m_connected.elapsed() / 1000) : 0;
}

void CallEngine::send(const QJsonObject &command)
{
    if (load())
        m_command(QJsonDocument(command).toJson(QJsonDocument::Compact).constData());
}

// Ringtone, ringback tone and the call's audio route follow the state.
void CallEngine::updateAudio(const QString &state)
{
    if (state != kIncoming && !state.isEmpty())
        m_audio.stopRinging();
    // The ringback tone while the person we call is being rung.
    if (state == QLatin1String("ringing") && !m_incoming)
        m_audio.startRingback();
    else
        m_audio.stopRingback();
    // The call is heard on the earpiece (or hands-free) from the moment it
    // is set up until it ends.
    if (state == QLatin1String("outgoing") || state == QLatin1String("connecting")
            || state == QLatin1String("connected"))
        m_audio.beginCall(m_speaker);
    if (state == kEnded || state.isEmpty())
        m_audio.endCall();
}

void CallEngine::setState(const QString &state)
{
    if (state == m_state)
        return;
    m_state = state;
    updateAudio(state);
    if (state == QLatin1String("connected")) {
        m_connected.start();
        m_ticker.start();
    } else if (state == kEnded) {
        m_ticker.stop();
        // The call screen shows "ended" briefly, then closes.
        QTimer::singleShot(kEndedShownMs, this, &CallEngine::closeEnded);
    }
    emit changed();
}

void CallEngine::closeEnded()
{
    if (m_state != kEnded)
        return;
    reset();
    emit changed();
}

// Forgets the call that is over.
void CallEngine::reset()
{
    m_incoming = false;
    m_readyToAccept = false;
    m_acceptPending = false;
    m_state.clear();
    m_thread.clear();
    m_title.clear();
    m_callId.clear();
    m_muted = false;
    m_speaker = false;
    m_video = false;
    m_camera = false;
    m_remoteVideo = false;
    m_connected.invalidate();
    QMutexLocker locker(&m_frameMutex);
    m_remoteFrame = QImage();
}

// Runs on a WebRTC thread: keep the newest picture, update the view once.
void CallEngine::frameCallback(void *context, uint32_t width, uint32_t height,
                               const uint8_t *rgba)
{
    auto *engine = static_cast<CallEngine *>(context);
    const QImage frame = QImage(rgba, static_cast<int>(width), static_cast<int>(height),
                                static_cast<int>(width) * 4, QImage::Format_RGBA8888).copy();
    QMutexLocker locker(&engine->m_frameMutex);
    engine->m_remoteFrame = frame;
    if (engine->m_framePending)
        return;
    engine->m_framePending = true;
    QMetaObject::invokeMethod(engine, "onRemoteFrame", Qt::QueuedConnection);
}

void CallEngine::onRemoteFrame()
{
    {
        QMutexLocker locker(&m_frameMutex);
        m_framePending = false;
    }
    emit remoteFrameChanged();
}

QImage CallEngine::remoteFrame() const
{
    QMutexLocker locker(&m_frameMutex);
    return m_remoteFrame;
}

// Runs on a RingRTC thread.
void CallEngine::eventCallback(void *context, const char *json)
{
    QMetaObject::invokeMethod(static_cast<CallEngine *>(context), "onLibraryEvent",
                              Qt::QueuedConnection, Q_ARG(QByteArray, QByteArray(json)));
}

void CallEngine::onLibraryEvent(const QByteArray &json)
{
    const QJsonObject event = QJsonDocument::fromJson(json).object();
    const QString name = event.value(QStringLiteral("ev")).toString();
    if (name == QLatin1String("signal")) {
        m_client->sendCallSignal(event);
    } else if (name == QLatin1String("remoteVideo")) {
        m_remoteVideo = event.value(QStringLiteral("enabled")).toBool();
        emit changed();
    } else if (name == QLatin1String("state")) {
        onStateEvent(event);
    }
}

void CallEngine::onStateEvent(const QJsonObject &event)
{
    const QString state = event.value(QStringLiteral("state")).toString();
    const QString callId = event.value(QStringLiteral("callId")).toString();
    qDebug() << "CallEngine: call" << state << event.value(QStringLiteral("reason")).toString();
    if (state == QLatin1String("ended") || state == QLatin1String("rejected")
            || state == QLatin1String("concluded")) {
        if (callId == m_callId)
            onCallOver();
        return;
    }
    if (state == kIncoming) {
        m_callId = callId;
        m_thread = QStringLiteral("c:") + event.value(QStringLiteral("peer")).toString();
        m_incoming = true;
        m_readyToAccept = false;
    }
    if (callId != m_callId)
        return;
    if (state == QLatin1String("ringing") && m_incoming) {
        // RingRTC takes the answer only from now on (connected, ringing
        // here); answer at once if the user already did.
        m_readyToAccept = true;
        if (m_acceptPending) {
            m_acceptPending = false;
            send({{QStringLiteral("cmd"), QStringLiteral("accept")},
                  {QStringLiteral("callId"), m_callId}});
        }
        return;
    }
    setState(state);
}

void CallEngine::onCallOver()
{
    if (m_state.isEmpty())
        return;
    if (m_state != kIncoming) {
        setState(kEnded);
        return;
    }
    // Never answered here: nothing to show.
    updateAudio(QString());
    reset();
    emit changed();
}

void CallEngine::onSignal(const QJsonObject &signal)
{
    if (!load())
        return;
    const QString kind = signal.value(QStringLiteral("kind")).toString();
    QJsonObject command = signal;
    command.remove(QStringLiteral("ev"));
    if (kind == QLatin1String("offer")) {
        // RingRTC needs the TURN servers before it takes the call.
        command.insert(QStringLiteral("cmd"), QStringLiteral("receivedOffer"));
        if (m_state.isEmpty()) {
            m_callId = signal.value(QStringLiteral("callId")).toString();
            m_thread = signal.value(QStringLiteral("thread")).toString();
            m_video = signal.value(QStringLiteral("video")).toBool();
        }
        m_pending = command;
        m_client->requestTurnServers();
        return;
    }
    static const QHash<QString, QString> commands{
        {QStringLiteral("answer"), QStringLiteral("receivedAnswer")},
        {QStringLiteral("ice"), QStringLiteral("receivedIce")},
        {QStringLiteral("hangup"), QStringLiteral("receivedHangup")},
        {QStringLiteral("busy"), QStringLiteral("receivedBusy")},
    };
    if (!commands.contains(kind))
        return;
    command.insert(QStringLiteral("cmd"), commands.value(kind));
    send(command);
}

void CallEngine::onTurnServers(const QJsonArray &servers, int localDeviceId)
{
    send({{QStringLiteral("cmd"), QStringLiteral("iceServers")},
          {QStringLiteral("servers"), servers}});
    if (m_pending.isEmpty())
        return;
    QJsonObject command = m_pending;
    m_pending = QJsonObject();
    if (!command.contains(QStringLiteral("localDeviceId")))
        command.insert(QStringLiteral("localDeviceId"), localDeviceId);
    send(command);
}

void CallEngine::accept()
{
    if (m_callId.isEmpty())
        return;
    m_client->callAnswered(m_callId);
    // A video call is answered with the camera on (and the loudspeaker).
    if (m_video) {
        setCamera(true);
        setSpeaker(true);
    }
    if (m_readyToAccept) {
        send({{QStringLiteral("cmd"), QStringLiteral("accept")},
              {QStringLiteral("callId"), m_callId}});
    } else {
        // RingRTC is still connecting; it gets the answer once it rings.
        m_acceptPending = true;
    }
    setState(QStringLiteral("connecting"));
}

void CallEngine::hangup()
{
    m_acceptPending = false;
    if (m_state == kIncoming || m_state.isEmpty())
        m_client->declineCall(m_callId);
    send({{QStringLiteral("cmd"), QStringLiteral("hangup")}});
    if (!m_state.isEmpty())
        setState(kEnded);
}

void CallEngine::startCall(const QString &thread, const QString &title, bool video)
{
    if (!m_state.isEmpty() || !thread.startsWith(QLatin1String("c:")) || !load())
        return;
    // Signal call ids are random 64-bit numbers; JSON carries them as text.
    m_callId = QString::number(QRandomGenerator::global()->generate64() >> 1);
    m_thread = thread;
    m_title = title;
    m_muted = false;
    m_video = video;
    m_incoming = false;
    m_pending = {{QStringLiteral("cmd"), QStringLiteral("call")},
                 {QStringLiteral("peer"), thread.mid(2)},
                 {QStringLiteral("callId"), m_callId},
                 {QStringLiteral("video"), video}};
    if (video) {
        m_speaker = true;
        setCamera(true);
    }
    m_client->requestTurnServers();
    m_client->callStarted(thread, video);
    setState(QStringLiteral("outgoing"));
}

void CallEngine::setCamera(bool on)
{
    m_camera = on;
    send({{QStringLiteral("cmd"), QStringLiteral("camera")},
          {QStringLiteral("enabled"), on}});
    emit changed();
}

void CallEngine::pushFrame(const QVariant &image)
{
    if (!m_camera || !m_pushFrame)
        return;
    QImage frame = image.value<QImage>();
    if (frame.isNull())
        return;
    // WebRTC wants even sizes.
    frame = frame.convertToFormat(QImage::Format_RGBA8888)
            .copy(0, 0, frame.width() & ~1, frame.height() & ~1);
    m_pushFrame(static_cast<uint32_t>(frame.width()), static_cast<uint32_t>(frame.height()),
                frame.constBits());
}

void CallEngine::setSpeaker(bool speaker)
{
    m_speaker = speaker;
    m_audio.setSpeaker(speaker);
    emit changed();
}

void CallEngine::stopRinging()
{
    m_audio.stopRinging();
    emit changed();
}

void CallEngine::setMuted(bool muted)
{
    m_muted = muted;
    send({{QStringLiteral("cmd"), QStringLiteral("mute")},
          {QStringLiteral("muted"), muted}});
    emit changed();
}
