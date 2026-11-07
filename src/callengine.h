// One-to-one calls ("Calls" in QML). The call itself runs in
// libutlangis_calls.so (Signal's RingRTC, see calls/src/lib.rs), which is
// loaded at run time; this class carries the signalling between it and the
// Signal backend (SignalClient) and keeps the state the call screen shows.

#ifndef CALLENGINE_H
#define CALLENGINE_H

#include <QElapsedTimer>
#include <QImage>
#include <QMutex>
#include <QVariant>
#include <QJsonArray>
#include <QJsonObject>
#include <QLibrary>
#include <QObject>
#include <QTimer>

#include "callaudio.h"
#include "utlangis_calls.h"

class SignalClient;

class CallEngine : public QObject
{
    Q_OBJECT
    // The library is there and works: calls can be answered and made.
    Q_PROPERTY(bool available READ available NOTIFY changed)
    // "" (no call), "incoming", "outgoing", "ringing", "connecting",
    // "connected", "ended".
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString thread READ thread NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(bool muted READ muted NOTIFY changed)
    // Hands-free: the call on the loudspeaker instead of the earpiece.
    Q_PROPERTY(bool speaker READ speaker NOTIFY changed)
    // A call rings here (ringtone playing).
    Q_PROPERTY(bool ringing READ ringing NOTIFY changed)
    // Video: our camera is on, the other side sends video (shown by
    // RemoteVideo).
    Q_PROPERTY(bool camera READ camera NOTIFY changed)
    Q_PROPERTY(bool remoteVideo READ remoteVideo NOTIFY changed)
    // Seconds since the call was connected.
    Q_PROPERTY(int seconds READ seconds NOTIFY tick)

public:
    CallEngine(SignalClient *client, QObject *parent = nullptr);
    ~CallEngine() override;

    bool available();
    QString state() const { return m_state; }
    QString thread() const { return m_thread; }
    QString title() const { return m_title; }
    bool muted() const { return m_muted; }
    bool speaker() const { return m_speaker; }
    bool ringing() const { return m_audio.ringing(); }
    bool camera() const { return m_camera; }
    bool remoteVideo() const { return m_remoteVideo; }
    // The other side's latest picture.
    QImage remoteFrame() const;
    int seconds() const;

    // Answers the ringing call.
    Q_INVOKABLE void accept();
    // Ends the call, or declines a ringing one.
    Q_INVOKABLE void hangup();
    Q_INVOKABLE void startCall(const QString &thread, const QString &title, bool video = false);
    Q_INVOKABLE void setCamera(bool on);
    // A camera picture to send (an ItemGrabResult's image).
    Q_INVOKABLE void pushFrame(const QVariant &image);
    Q_INVOKABLE void setMuted(bool muted);
    Q_INVOKABLE void setSpeaker(bool speaker);
    // Silences the ringtone (the call keeps ringing elsewhere).
    Q_INVOKABLE void stopRinging();

    Q_INVOKABLE void onLibraryEvent(const QByteArray &json);
    Q_INVOKABLE void onRemoteFrame();

signals:
    void changed();
    void tick();
    void remoteFrameChanged();

private:
    bool load();
    void send(const QJsonObject &command);
    void setState(const QString &state);
    void updateAudio(const QString &state);
    void closeEnded();
    void reset();
    void onStateEvent(const QJsonObject &event);
    void onCallOver();
    void onSignal(const QJsonObject &signal);
    void onIncomingCall(const QString &callId, const QString &thread, const QString &title);
    void onRingingEnded();
    void onTurnServers(const QJsonArray &servers, int localDeviceId);
    static void eventCallback(void *context, const char *json);
    static void frameCallback(void *context, uint32_t width, uint32_t height,
                              const uint8_t *rgba);

    SignalClient *m_client;
    QLibrary m_library;
    bool m_tried = false;
    bool m_started = false;
    // The library's functions (calls/include/utlangis_calls.h).
    using StartFn = decltype(&ut_calls_start);
    using CommandFn = decltype(&ut_calls_command);
    using StopFn = decltype(&ut_calls_stop);
    using SetVideoCallbackFn = decltype(&ut_calls_set_video_callback);
    using PushFrameFn = decltype(&ut_calls_push_frame);
    PushFrameFn m_pushFrame = nullptr;
    StartFn m_start = nullptr;
    CommandFn m_command = nullptr;
    StopFn m_stop = nullptr;

    QString m_state;
    QString m_thread;
    QString m_title;
    QString m_callId;
    bool m_muted = false;
    bool m_speaker = false;
    bool m_video = false;
    bool m_camera = false;
    bool m_remoteVideo = false;
    mutable QMutex m_frameMutex;
    QImage m_remoteFrame;
    bool m_framePending = false;
    CallAudio m_audio;
    QElapsedTimer m_connected;
    QTimer m_ticker;
    // Waits for TURN servers before it goes to RingRTC: an offer received,
    // or a call we start.
    QJsonObject m_pending;
    // Answered before RingRTC had the call ready.
    bool m_acceptPending = false;
    // The current call is incoming, and RingRTC can take the answer (it
    // reported "ringing": connected, waiting for us).
    bool m_incoming = false;
    bool m_readyToAccept = false;
};

#endif
