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

public:
    explicit VoiceNotes(const QString &recordDir, QObject *parent = nullptr);
    ~VoiceNotes() override;

    bool recording() const { return m_recorder != nullptr; }
    int recordedMs() const;
    QString playingPath() const { return m_playingPath; }
    int positionMs() const { return m_positionMs; }
    int durationMs() const { return m_durationMs; }

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
    void failed(const QString &message);

private:
    void finishRecording();
    void pollPlayer();

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
};

#endif
