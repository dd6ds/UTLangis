#include "callaudio.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QUrl>

#include <gst/gst.h>
#include <pulse/pulseaudio.h>

namespace {

const char *const kEarpiece = "output-earpiece";
const char *const kSpeaker = "output-speaker";
// The droid sink parks its port while nothing plays.
const char *const kParking = "output-parking";
const int kRingPollMs = 200;
const char *const kRingbackPipeline =
        "audiotestsrc wave=sine freq=425 volume=0.25 ! audioconvert ! pulsesink";
const int kRingbackOnMs = 1000;
const int kRingbackOffMs = 4000;
// Shared with voice messages (src/voicenotes.cpp).
const char *const kMicGainKey = "voice/micGainDb";
const int kDefaultMicGainDb = 12;

// The ringtone: Lomiri's default, or any ringtone the system has.
QString ringtonePath()
{
    const QString dir = QStringLiteral("/usr/share/sounds/ubports/ringtones");
    const QString preferred = dir + QStringLiteral("/Ubuntu.ogg");
    if (QFile::exists(preferred))
        return preferred;
    const QStringList others = QDir(dir).entryList({QStringLiteral("*.ogg")}, QDir::Files);
    return others.isEmpty() ? QString() : dir + QLatin1Char('/') + others.first();
}

// Wakes the waiting thread when a PulseAudio operation or state change
// is done.
void signalLoop(pa_threaded_mainloop *loop)
{
    pa_threaded_mainloop_signal(loop, 0);
}

void waitFor(pa_threaded_mainloop *loop, pa_operation *operation)
{
    if (!operation)
        return;
    while (pa_operation_get_state(operation) == PA_OPERATION_RUNNING)
        pa_threaded_mainloop_wait(loop);
    pa_operation_unref(operation);
}

struct Query {
    pa_threaded_mainloop *loop;
    QString result;
};

} // namespace

CallAudio::CallAudio(QObject *parent) : QObject(parent)
{
    m_ringTicker.setInterval(kRingPollMs);
    connect(&m_ringTicker, &QTimer::timeout, this, &CallAudio::pollRinger);
    m_ringbackTimer.setSingleShot(true);
    connect(&m_ringbackTimer, &QTimer::timeout, this, [this] {
        if (!m_ringback)
            return;
        m_ringbackOn = !m_ringbackOn;
        gst_element_set_state(m_ringback, m_ringbackOn ? GST_STATE_PLAYING : GST_STATE_PAUSED);
        m_ringbackTimer.start(m_ringbackOn ? kRingbackOnMs : kRingbackOffMs);
    });
}

void CallAudio::startRingback()
{
    if (m_ringback)
        return;
    GError *error = nullptr;
    m_ringback = gst_parse_launch(kRingbackPipeline, &error);
    if (!m_ringback) {
        qWarning() << "CallAudio: no ringback tone:" << (error ? error->message : "");
        g_clear_error(&error);
        return;
    }
    m_ringbackOn = true;
    gst_element_set_state(m_ringback, GST_STATE_PLAYING);
    m_ringbackTimer.start(kRingbackOnMs);
}

void CallAudio::stopRingback()
{
    m_ringbackTimer.stop();
    if (!m_ringback)
        return;
    gst_element_set_state(m_ringback, GST_STATE_NULL);
    gst_object_unref(m_ringback);
    m_ringback = nullptr;
}

CallAudio::~CallAudio()
{
    stopRinging();
    stopRingback();
    endCall();
    if (m_loop) {
        pa_threaded_mainloop_stop(m_loop);
        if (m_context) {
            pa_context_disconnect(m_context);
            pa_context_unref(m_context);
        }
        pa_threaded_mainloop_free(m_loop);
    }
}

// --- Ringtone ---------------------------------------------------------------

void CallAudio::startRinging()
{
    if (m_ringer)
        return;
    const QString path = ringtonePath();
    if (path.isEmpty())
        return;
    m_ringer = gst_element_factory_make("playbin", nullptr);
    if (!m_ringer)
        return;
    g_object_set(m_ringer, "uri", QUrl::fromLocalFile(path).toEncoded().constData(), nullptr);
    gst_element_set_state(m_ringer, GST_STATE_PLAYING);
    m_ringTicker.start();
}

void CallAudio::stopRinging()
{
    m_ringTicker.stop();
    if (!m_ringer)
        return;
    gst_element_set_state(m_ringer, GST_STATE_NULL);
    gst_object_unref(m_ringer);
    m_ringer = nullptr;
}

// Starts the ringtone over when it has played to the end.
void CallAudio::pollRinger()
{
    if (!m_ringer)
        return;
    GstBus *bus = gst_element_get_bus(m_ringer);
    GstMessage *message = gst_bus_pop_filtered(
            bus, static_cast<GstMessageType>(GST_MESSAGE_EOS | GST_MESSAGE_ERROR));
    gst_object_unref(bus);
    if (!message)
        return;
    const bool error = GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR;
    gst_message_unref(message);
    if (error) {
        qWarning() << "CallAudio: the ringtone cannot be played";
        stopRinging();
        return;
    }
    gst_element_seek_simple(m_ringer, GST_FORMAT_TIME,
                            static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH), 0);
}

// --- Earpiece / loudspeaker ---------------------------------------------------

bool CallAudio::connectPulse()
{
    if (m_context)
        return pa_context_get_state(m_context) == PA_CONTEXT_READY;
    m_loop = pa_threaded_mainloop_new();
    if (!m_loop || pa_threaded_mainloop_start(m_loop) < 0)
        return false;
    pa_threaded_mainloop_lock(m_loop);
    m_context = pa_context_new(pa_threaded_mainloop_get_api(m_loop), "UT Langis");
    pa_context_set_state_callback(
            m_context, [](pa_context *, void *loop) {
                signalLoop(static_cast<pa_threaded_mainloop *>(loop));
            }, m_loop);
    pa_context_connect(m_context, nullptr, PA_CONTEXT_NOFLAGS, nullptr);
    pa_context_state_t state;
    while ((state = pa_context_get_state(m_context)) != PA_CONTEXT_READY
           && PA_CONTEXT_IS_GOOD(state))
        pa_threaded_mainloop_wait(m_loop);
    pa_threaded_mainloop_unlock(m_loop);
    if (state != PA_CONTEXT_READY)
        qWarning() << "CallAudio: no connection to PulseAudio";
    return state == PA_CONTEXT_READY;
}

// Call with the main loop locked.
QString CallAudio::defaultSink()
{
    Query query{m_loop, QString()};
    waitFor(m_loop, pa_context_get_server_info(
            m_context, [](pa_context *, const pa_server_info *info, void *data) {
                auto *q = static_cast<Query *>(data);
                if (info && info->default_sink_name)
                    q->result = QString::fromUtf8(info->default_sink_name);
                signalLoop(q->loop);
            }, &query));
    return query.result;
}

// Call with the main loop locked.
QString CallAudio::activePort(const QString &sink)
{
    Query query{m_loop, QString()};
    const QByteArray name = sink.toUtf8();
    waitFor(m_loop, pa_context_get_sink_info_by_name(
            m_context, name.constData(),
            [](pa_context *, const pa_sink_info *info, int eol, void *data) {
                auto *q = static_cast<Query *>(data);
                if (!eol && info && info->active_port)
                    q->result = QString::fromUtf8(info->active_port->name);
                signalLoop(q->loop);
            }, &query));
    return query.result;
}

// Call with the main loop locked.
void CallAudio::setPort(const QString &sink, const QString &port)
{
    const QByteArray sinkName = sink.toUtf8();
    const QByteArray portName = port.toUtf8();
    waitFor(m_loop, pa_context_set_sink_port_by_name(
            m_context, sinkName.constData(), portName.constData(),
            [](pa_context *, int success, void *loop) {
                if (!success)
                    qWarning() << "CallAudio: could not switch the audio output";
                signalLoop(static_cast<pa_threaded_mainloop *>(loop));
            }, m_loop));
}

// Call with the main loop locked.
QString CallAudio::defaultSource()
{
    Query query{m_loop, QString()};
    waitFor(m_loop, pa_context_get_server_info(
            m_context, [](pa_context *, const pa_server_info *info, void *data) {
                auto *q = static_cast<Query *>(data);
                if (info && info->default_source_name)
                    q->result = QString::fromUtf8(info->default_source_name);
                signalLoop(q->loop);
            }, &query));
    return query.result;
}

namespace {
struct VolumeQuery {
    pa_threaded_mainloop *loop;
    pa_cvolume volume;
    bool found;
};
}

// Call with the main loop locked.
bool CallAudio::sourceVolume(const QString &source, pa_cvolume *volume)
{
    VolumeQuery query{m_loop, {}, false};
    const QByteArray name = source.toUtf8();
    waitFor(m_loop, pa_context_get_source_info_by_name(
            m_context, name.constData(),
            [](pa_context *, const pa_source_info *info, int eol, void *data) {
                auto *q = static_cast<VolumeQuery *>(data);
                if (!eol && info) {
                    q->volume = info->volume;
                    q->found = true;
                }
                signalLoop(q->loop);
            }, &query));
    if (query.found)
        *volume = query.volume;
    return query.found;
}

// Call with the main loop locked.
void CallAudio::setSourceVolume(const QString &source, const pa_cvolume &volume)
{
    const QByteArray name = source.toUtf8();
    waitFor(m_loop, pa_context_set_source_volume_by_name(
            m_context, name.constData(), &volume,
            [](pa_context *, int success, void *loop) {
                if (!success)
                    qWarning() << "CallAudio: could not set the microphone volume";
                signalLoop(static_cast<pa_threaded_mainloop *>(loop));
            }, m_loop));
}

void CallAudio::beginCall(bool speaker)
{
    if (!m_previousPort.isEmpty() || !connectPulse())
        return;
    pa_threaded_mainloop_lock(m_loop);
    m_sink = defaultSink();
    m_previousPort = m_sink.isEmpty() ? QString() : activePort(m_sink);
    // Only phones' own earpiece/speaker are switched; a headset keeps the call.
    m_routing = m_previousPort == QLatin1String(kSpeaker)
            || m_previousPort == QLatin1String(kEarpiece)
            || m_previousPort == QLatin1String(kParking);
    // Afterwards the loudspeaker again; the sink parks it by itself.
    if (m_previousPort == QLatin1String(kParking))
        m_previousPort = QLatin1String(kSpeaker);
    qDebug() << "CallAudio: call on" << m_sink << "port was" << m_previousPort;
    if (m_routing)
        setPort(m_sink, QLatin1String(speaker ? kSpeaker : kEarpiece));

    // Louder microphone for the call.
    m_source = defaultSource();
    m_previousSourceVolume.channels = 0;
    pa_cvolume volume;
    if (!m_source.isEmpty() && sourceVolume(m_source, &volume)) {
        m_previousSourceVolume = volume;
        const int gainDb = QSettings().value(QLatin1String(kMicGainKey), kDefaultMicGainDb).toInt();
        if (gainDb > 0) {
            pa_cvolume louder = volume;
            pa_cvolume_set(&louder, volume.channels,
                           pa_sw_volume_multiply(pa_cvolume_max(&volume),
                                                 pa_sw_volume_from_dB(gainDb)));
            setSourceVolume(m_source, louder);
            qDebug() << "CallAudio: microphone +" << gainDb << "dB";
        }
    }
    pa_threaded_mainloop_unlock(m_loop);
}

void CallAudio::setSpeaker(bool speaker)
{
    if (!m_routing || !m_context)
        return;
    pa_threaded_mainloop_lock(m_loop);
    setPort(m_sink, QLatin1String(speaker ? kSpeaker : kEarpiece));
    pa_threaded_mainloop_unlock(m_loop);
}

void CallAudio::endCall()
{
    if (m_previousPort.isEmpty() || !m_context)
        return;
    pa_threaded_mainloop_lock(m_loop);
    if (m_routing)
        setPort(m_sink, m_previousPort);
    if (m_previousSourceVolume.channels > 0)
        setSourceVolume(m_source, m_previousSourceVolume);
    m_previousSourceVolume.channels = 0;
    pa_threaded_mainloop_unlock(m_loop);
    m_previousPort.clear();
    m_routing = false;
}
