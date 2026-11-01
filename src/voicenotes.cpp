// Recording and playback of voice messages with GStreamer, see voicenotes.h.

#include "voicenotes.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QUrl>

#include <gst/gst.h>

namespace {

// Signal's Android app sends voice messages as AAC in an ADTS stream with
// the content type audio/aac; recipients on every platform can play that.
const char *const kRecordPipeline =
        "pulsesrc ! audioconvert ! audioresample ! audio/x-raw,rate=44100,channels=1 "
        "! voaacenc bitrate=32000 ! audio/mpeg,stream-format=adts ! filesink name=sink";
const char *const kRecordPrefix = "voice-";
const char *const kRecordSuffix = ".aac";
// Shorter recordings are taken as an accidental tap and dropped.
const int kMinRecordingMs = 1000;
const int kTickMs = 200;
// How long stopping may wait for the encoder to write the end of the file.
const GstClockTime kFinishTimeout = 2 * GST_SECOND;

// Pops a pending error from a pipeline's bus, or returns "" if there is none.
QString pendingError(GstElement *pipeline)
{
    GstBus *bus = gst_element_get_bus(pipeline);
    GstMessage *message = gst_bus_pop_filtered(bus, GST_MESSAGE_ERROR);
    gst_object_unref(bus);
    if (!message)
        return QString();
    GError *error = nullptr;
    gst_message_parse_error(message, &error, nullptr);
    const QString text = QString::fromUtf8(error ? error->message : "unknown error");
    g_clear_error(&error);
    gst_message_unref(message);
    return text;
}

void destroy(GstElement *&pipeline)
{
    if (!pipeline)
        return;
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    pipeline = nullptr;
}

} // namespace

VoiceNotes::VoiceNotes(const QString &recordDir, QObject *parent)
    : QObject(parent), m_recordDir(recordDir)
{
    gst_init(nullptr, nullptr);
    QDir dir(m_recordDir);
    dir.mkpath(QStringLiteral("."));
    // Recordings are copied by the backend when they are sent; what is left
    // over from earlier runs is not needed any more.
    const QStringList leftovers = dir.entryList(
            {QString::fromLatin1(kRecordPrefix) + QLatin1Char('*')}, QDir::Files);
    for (const QString &name : leftovers)
        dir.remove(name);

    m_recordTicker.setInterval(kTickMs);
    connect(&m_recordTicker, &QTimer::timeout, this, [this] {
        const QString error = m_recorder ? pendingError(m_recorder) : QString();
        if (!error.isEmpty()) {
            qWarning() << "VoiceNotes: recording failed:" << error;
            cancelRecording();
            emit failed(error);
            return;
        }
        emit recordedMsChanged();
    });
    m_playTicker.setInterval(kTickMs);
    connect(&m_playTicker, &QTimer::timeout, this, &VoiceNotes::pollPlayer);
}

VoiceNotes::~VoiceNotes()
{
    destroy(m_recorder);
    destroy(m_player);
}

int VoiceNotes::recordedMs() const
{
    return m_recorder ? static_cast<int>(m_recordClock.elapsed()) : 0;
}

bool VoiceNotes::startRecording()
{
    if (m_recorder)
        return true;
    stopPlaying();
    GError *error = nullptr;
    m_recorder = gst_parse_launch(kRecordPipeline, &error);
    if (!m_recorder) {
        const QString text = QString::fromUtf8(error ? error->message : "pipeline");
        g_clear_error(&error);
        qWarning() << "VoiceNotes: cannot create recorder:" << text;
        emit failed(text);
        return false;
    }
    m_recordPath = m_recordDir + QLatin1Char('/') + QString::fromLatin1(kRecordPrefix)
            + QString::number(QDateTime::currentMSecsSinceEpoch())
            + QString::fromLatin1(kRecordSuffix);
    GstElement *sink = gst_bin_get_by_name(GST_BIN(m_recorder), "sink");
    g_object_set(sink, "location", m_recordPath.toUtf8().constData(), nullptr);
    gst_object_unref(sink);

    if (gst_element_set_state(m_recorder, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        const QString text = pendingError(m_recorder);
        cancelRecording();
        qWarning() << "VoiceNotes: cannot start recording:" << text;
        emit failed(text);
        return false;
    }
    m_recordClock.start();
    m_recordTicker.start();
    emit recordingChanged();
    emit recordedMsChanged();
    return true;
}

// Ends the stream so the encoder writes everything out, then releases the
// microphone.
void VoiceNotes::finishRecording()
{
    m_recordTicker.stop();
    if (!m_recorder)
        return;
    gst_element_send_event(m_recorder, gst_event_new_eos());
    GstBus *bus = gst_element_get_bus(m_recorder);
    GstMessage *message = gst_bus_timed_pop_filtered(
            bus, kFinishTimeout,
            static_cast<GstMessageType>(GST_MESSAGE_EOS | GST_MESSAGE_ERROR));
    if (message)
        gst_message_unref(message);
    gst_object_unref(bus);
    destroy(m_recorder);
    emit recordingChanged();
    emit recordedMsChanged();
}

QString VoiceNotes::stopRecording()
{
    if (!m_recorder)
        return QString();
    const qint64 length = m_recordClock.elapsed();
    finishRecording();
    if (length < kMinRecordingMs || !QFile::exists(m_recordPath)) {
        QFile::remove(m_recordPath);
        return QString();
    }
    return QUrl::fromLocalFile(m_recordPath).toString();
}

void VoiceNotes::cancelRecording()
{
    m_recordTicker.stop();
    if (m_recorder) {
        destroy(m_recorder);
        emit recordingChanged();
        emit recordedMsChanged();
    }
    QFile::remove(m_recordPath);
}

void VoiceNotes::togglePlay(const QString &path)
{
    const bool wasPlaying = path == m_playingPath;
    stopPlaying();
    if (wasPlaying || m_recorder)
        return;

    m_player = gst_element_factory_make("playbin", nullptr);
    if (!m_player) {
        emit failed(QStringLiteral("playbin missing"));
        return;
    }
    const QByteArray uri = QUrl::fromLocalFile(path).toEncoded();
    g_object_set(m_player, "uri", uri.constData(), nullptr);
    if (gst_element_set_state(m_player, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        const QString text = pendingError(m_player);
        destroy(m_player);
        qWarning() << "VoiceNotes: cannot play" << path << text;
        emit failed(text);
        return;
    }
    m_playingPath = path;
    m_positionMs = 0;
    m_durationMs = 0;
    m_playTicker.start();
    emit playingChanged();
    emit positionChanged();
}

void VoiceNotes::stopPlaying()
{
    m_playTicker.stop();
    if (!m_player)
        return;
    destroy(m_player);
    m_playingPath.clear();
    m_positionMs = 0;
    emit playingChanged();
    emit positionChanged();
}

void VoiceNotes::pollPlayer()
{
    if (!m_player)
        return;
    GstBus *bus = gst_element_get_bus(m_player);
    GstMessage *message = gst_bus_pop_filtered(
            bus, static_cast<GstMessageType>(GST_MESSAGE_EOS | GST_MESSAGE_ERROR));
    gst_object_unref(bus);
    if (message) {
        if (GST_MESSAGE_TYPE(message) == GST_MESSAGE_ERROR) {
            GError *error = nullptr;
            gst_message_parse_error(message, &error, nullptr);
            qWarning() << "VoiceNotes: playback failed:" << (error ? error->message : "");
            emit failed(QString::fromUtf8(error ? error->message : ""));
            g_clear_error(&error);
        }
        gst_message_unref(message);
        stopPlaying();
        return;
    }
    gint64 position = 0;
    gint64 duration = 0;
    if (gst_element_query_position(m_player, GST_FORMAT_TIME, &position))
        m_positionMs = static_cast<int>(position / GST_MSECOND);
    if (gst_element_query_duration(m_player, GST_FORMAT_TIME, &duration))
        m_durationMs = static_cast<int>(duration / GST_MSECOND);
    emit positionChanged();
}
