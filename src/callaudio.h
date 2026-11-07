// Sound around calls (used by CallEngine): the ringtone while a call rings,
// and where the call is heard: the earpiece, or the loudspeaker for hands-
// free talking. The route is the active port of PulseAudio's default sink
// (Halium's droid sink has output-earpiece and output-speaker); the port
// that was active before the call is restored afterwards. A headset that is
// plugged in is left alone. The microphone (default source) is amplified by
// the microphone gain of the settings during calls, as phone microphones
// pick up a voice quietly.

#ifndef CALLAUDIO_H
#define CALLAUDIO_H

#include <QObject>
#include <QString>
#include <QTimer>

#include <pulse/volume.h>

typedef struct _GstElement GstElement;
struct pa_threaded_mainloop;
struct pa_context;

class CallAudio : public QObject
{
    Q_OBJECT

public:
    explicit CallAudio(QObject *parent = nullptr);
    ~CallAudio() override;

    void startRinging();
    void stopRinging();

    // The ringback tone while the person we call is being rung (European
    // style: 425 Hz, one second on, four off).
    void startRingback();
    void stopRingback();
    bool ringing() const { return m_ringer != nullptr; }

    // A call starts being heard: earpiece, or the loudspeaker if `speaker`.
    void beginCall(bool speaker);
    void setSpeaker(bool speaker);
    // Back to the route from before the call.
    void endCall();

private:
    bool connectPulse();
    QString defaultSink();
    QString activePort(const QString &sink);
    void setPort(const QString &sink, const QString &port);
    QString defaultSource();
    bool sourceVolume(const QString &source, pa_cvolume *volume);
    void setSourceVolume(const QString &source, const pa_cvolume &volume);
    void pollRinger();

    GstElement *m_ringer = nullptr;
    QTimer m_ringTicker;
    GstElement *m_ringback = nullptr;
    QTimer m_ringbackTimer;
    bool m_ringbackOn = false;

    pa_threaded_mainloop *m_loop = nullptr;
    pa_context *m_context = nullptr;
    QString m_sink;
    // Port before the call; "" while no call is routed.
    QString m_previousPort;
    // The call goes to earpiece/speaker ports (false: a headset is used).
    bool m_routing = false;
    QString m_source;
    // Microphone volume before the call (channels == 0: not changed).
    pa_cvolume m_previousSourceVolume{};
};

#endif
