// Notifications for new messages ("Notifications" in QML): notification
// cards through Lomiri's Postal service (AppArmor policy group
// "push-notification-client"), the chosen sound, and muting - for all
// conversations or for single ones. Settings are stored in QSettings.
//
// Lomiri suspends apps in the background, so notifications only appear
// while the app is allowed to run - see the README.

#ifndef NOTIFIER_H
#define NOTIFIER_H

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>

typedef struct _GstElement GstElement;

class Notifier : public QObject
{
    Q_OBJECT
    // false = no notifications at all.
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY settingsChanged)
    // "default" = the phone's notification sound, "" = silent, otherwise the
    // path of a sound file from `sounds`.
    Q_PROPERTY(QString sound READ sound WRITE setSound NOTIFY settingsChanged)
    // [{ name, path }] of the notification sounds installed on the phone.
    Q_PROPERTY(QVariantList sounds READ sounds CONSTANT)
    // Thread keys of muted conversations.
    Q_PROPERTY(QStringList mutedThreads READ mutedThreads NOTIFY settingsChanged)

public:
    explicit Notifier(QObject *parent = nullptr);
    ~Notifier() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QString sound() const { return m_sound; }
    void setSound(const QString &sound);
    QVariantList sounds() const { return m_sounds; }
    QStringList mutedThreads() const { return m_muted; }

    Q_INVOKABLE void setMuted(const QString &thread, bool muted);
    // Plays a sound file once, e.g. when it is picked in the settings.
    Q_INVOKABLE void preview(const QString &path);

    // title: the conversation; sender: who wrote it in a group ("" in a
    // one-to-one chat); text: "" for messages with only attachments.
    void notify(const QString &thread, const QString &title, const QString &sender,
                const QString &text);

signals:
    void settingsChanged();

private:
    static QString appId();
    static QVariantList findSounds();
    void post(const QString &title, const QString &body, bool systemSound) const;
    void playFile(const QString &path);
    void save() const;

    bool m_enabled = true;
    QString m_sound;
    QStringList m_muted;
    QVariantList m_sounds;
    GstElement *m_player = nullptr;
    QTimer m_releasePlayer;
};

#endif
