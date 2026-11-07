// Voice messages ("Voice" in QML): records from the microphone to an AAC
// file as Signal's apps send them, and plays received or sent audio
// attachments. Both run GStreamer pipelines in the app itself, so playback
// does not depend on the system media service being able to read the app's
// private files.

#ifndef VOICENOTES_H
#define VOICENOTES_H

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

typedef struct _GstElement GstElement;

class VoiceNotes : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    // Length of the recording so far, in milliseconds.
    Q_PROPERTY(int recordedMs READ recordedMs NOTIFY recordedMsChanged)
    // File currently playing ("" = none).
    Q_PROPERTY(QString playingPath READ playingPath NOTIFY playingChanged)
    // Playback position and length of the playing file, in milliseconds.
    Q_PROPERTY(int positionMs READ positionMs NOTIFY positionChanged)
    Q_PROPERTY(int durationMs READ durationMs NOTIFY positionChanged)
    // Microphone gain for recordings, in dB (saved).
    Q_PROPERTY(int micGainDb READ micGainDb WRITE setMicGainDb NOTIFY micGainDbChanged)
    Q_PROPERTY(int micGainMinDb READ micGainMinDb CONSTANT)
    Q_PROPERTY(int micGainMaxDb READ micGainMaxDb CONSTANT)
    // Extra loudness for playing voice messages, in dB (saved).
    Q_PROPERTY(int playbackGainDb READ playbackGainDb WRITE setPlaybackGainDb
               NOTIFY playbackGainDbChanged)
    Q_PROPERTY(int playbackGainMaxDb READ playbackGainMaxDb CONSTANT)
    // Peak level of the recording right now, in dBFS (-60 = silence).
    Q_PROPERTY(qreal levelDb READ levelDb NOTIFY levelChanged)

public:
    explicit VoiceNotes(const QString &recordDir, QObject *parent = nullptr);
    ~VoiceNotes() override;

    bool recording() const { return m_recorder != nullptr; }
    int recordedMs() const;
    QString playingPath() const { return m_playingPath; }
    int positionMs() const { return m_positionMs; }
    int durationMs() const { return m_durationMs; }
    int micGainDb() const { return m_micGainDb; }
    void setMicGainDb(int db);
    int micGainMinDb() const;
    int micGainMaxDb() const;
    int playbackGainDb() const { return m_playbackGainDb; }
    void setPlaybackGainDb(int db);
    int playbackGainMaxDb() const;
    qreal levelDb() const { return m_levelDb; }

    // Returns false (and emits failed) if the microphone cannot be used.
    Q_INVOKABLE bool startRecording();
    // Finishes the file and returns its file:// URL, or "" if the recording
    // was too short to be meant.
    Q_INVOKABLE QString stopRecording();
    Q_INVOKABLE void cancelRecording();

    // Plays `path`; calling it for the playing file stops it.
    Q_INVOKABLE void togglePlay(const QString &path);
    Q_INVOKABLE void stopPlaying();

signals:
    void recordingChanged();
    void recordedMsChanged();
    void playingChanged();
    void positionChanged();
    void micGainDbChanged();
    void playbackGainDbChanged();
    void levelChanged();
    void failed(const QString &message);

private:
    void finishRecording();
    void pollPlayer();
    void pollLevel();

    QString m_recordDir;
    QString m_recordPath;
    GstElement *m_recorder = nullptr;
    QElapsedTimer m_recordClock;
    QTimer m_recordTicker;

    GstElement *m_player = nullptr;
    QString m_playingPath;
    QTimer m_playTicker;
    int m_positionMs = 0;
    int m_durationMs = 0;
    int m_micGainDb = 0;
    int m_playbackGainDb = 0;
    qreal m_levelDb = -60;
};

#endif
