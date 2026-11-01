// Notification cards, sounds and muting, see notifier.h.

#include "notifier.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QUrl>

#include <gst/gst.h>

namespace {

const QString kPostalService = QStringLiteral("com.lomiri.Postal");
const QString kPostalPathPrefix = QStringLiteral("/com/lomiri/Postal/");
const QString kPostalInterface = QStringLiteral("com.lomiri.Postal");
// Used when not started by lomiri-app-launch (desktop test runs).
const QString kFallbackAppId = QStringLiteral("utlangis_utlangis");

const QString kDefaultSound = QStringLiteral("default");
const QString kEnabledKey = QStringLiteral("notifications/enabled");
const QString kSoundKey = QStringLiteral("notifications/sound");
const QString kMutedKey = QStringLiteral("notifications/muted");

// Notification sounds of Lomiri (Ubuntu Touch 20.04 and later) and of
// older Ubuntu Touch releases.
const char *const kSoundDirs[] = {
    "/usr/share/sounds/lomiri/notifications",
    "/usr/share/sounds/ubuntu/notifications",
};

// The playbin is kept for a while after a sound so repeated messages do
// not set up the audio output each time.
const int kReleasePlayerMs = 10000;

} // namespace

Notifier::Notifier(QObject *parent) : QObject(parent), m_sounds(findSounds())
{
    gst_init(nullptr, nullptr);
    QSettings settings;
    m_enabled = settings.value(kEnabledKey, true).toBool();
    m_sound = settings.value(kSoundKey, kDefaultSound).toString();
    m_muted = settings.value(kMutedKey).toStringList();

    m_releasePlayer.setSingleShot(true);
    m_releasePlayer.setInterval(kReleasePlayerMs);
    connect(&m_releasePlayer, &QTimer::timeout, this, [this] {
        if (!m_player)
            return;
        gst_element_set_state(m_player, GST_STATE_NULL);
        gst_object_unref(m_player);
        m_player = nullptr;
    });
}

Notifier::~Notifier()
{
    if (m_player) {
        gst_element_set_state(m_player, GST_STATE_NULL);
        gst_object_unref(m_player);
    }
}

QVariantList Notifier::findSounds()
{
    QVariantList sounds;
    for (const char *dirName : kSoundDirs) {
        const QFileInfoList files = QDir(QString::fromLatin1(dirName))
                .entryInfoList({QStringLiteral("*.ogg"), QStringLiteral("*.wav")},
                               QDir::Files, QDir::Name);
        for (const QFileInfo &file : files) {
            sounds.append(QVariantMap{{QStringLiteral("name"), file.completeBaseName()},
                                      {QStringLiteral("path"), file.absoluteFilePath()}});
        }
        if (!sounds.isEmpty())
            break;
    }
    return sounds;
}

void Notifier::save() const
{
    QSettings settings;
    settings.setValue(kEnabledKey, m_enabled);
    settings.setValue(kSoundKey, m_sound);
    settings.setValue(kMutedKey, m_muted);
}

void Notifier::setEnabled(bool enabled)
{
    if (enabled == m_enabled)
        return;
    m_enabled = enabled;
    save();
    emit settingsChanged();
}

void Notifier::setSound(const QString &sound)
{
    if (sound == m_sound)
        return;
    m_sound = sound;
    save();
    emit settingsChanged();
}

void Notifier::setMuted(const QString &thread, bool muted)
{
    if (muted == m_muted.contains(thread))
        return;
    if (muted)
        m_muted.append(thread);
    else
        m_muted.removeAll(thread);
    save();
    emit settingsChanged();
}

void Notifier::preview(const QString &path)
{
    if (!path.isEmpty() && path != kDefaultSound)
        playFile(path);
}

void Notifier::playFile(const QString &path)
{
    if (!m_player) {
        m_player = gst_element_factory_make("playbin", nullptr);
        if (!m_player) {
            qWarning() << "Notifier: playbin missing, no notification sound";
            return;
        }
    }
    gst_element_set_state(m_player, GST_STATE_NULL);
    const QByteArray uri = QUrl::fromLocalFile(path).toEncoded();
    g_object_set(m_player, "uri", uri.constData(), nullptr);
    if (gst_element_set_state(m_player, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE)
        qWarning() << "Notifier: cannot play" << path;
    m_releasePlayer.start();
}

void Notifier::notify(const QString &thread, const QString &title, const QString &sender,
                      const QString &text)
{
    if (!m_enabled || m_muted.contains(thread))
        return;
    QString body = text.isEmpty() ? QCoreApplication::translate("Notifier", "Attachment")
                                  : text;
    if (!sender.isEmpty() && sender != title)
        body = sender + QStringLiteral(": ") + body;
    const QString summary = title.isEmpty()
            ? QCoreApplication::translate("Notifier", "New message") : title;

    // A chosen sound file is played by the app itself: Postal only knows the
    // system sound or files inside the app package.
    const bool systemSound = m_sound == kDefaultSound;
    if (!systemSound && !m_sound.isEmpty())
        playFile(m_sound);
    post(summary, body, systemSound);
}

// Postal wants "<package>_<app>"; APP_ID also carries the version.
QString Notifier::appId()
{
    const QStringList parts = qEnvironmentVariable("APP_ID").split(QLatin1Char('_'));
    if (parts.size() < 2)
        return kFallbackAppId;
    return parts.at(0) + QLatin1Char('_') + parts.at(1);
}

void Notifier::post(const QString &title, const QString &body, bool systemSound) const
{
    const QJsonObject card{{QStringLiteral("summary"), title},
                           {QStringLiteral("body"), body},
                           {QStringLiteral("popup"), true},
                           {QStringLiteral("persist"), true}};
    const QJsonObject notification{{QStringLiteral("card"), card},
                                   {QStringLiteral("sound"), systemSound},
                                   {QStringLiteral("vibrate"), true}};
    const QJsonObject message{{QStringLiteral("notification"), notification}};

    const QString id = appId();
    // The object path is the package name; utlangis has no characters that
    // would need D-Bus escaping.
    QDBusMessage call = QDBusMessage::createMethodCall(
                kPostalService, kPostalPathPrefix + id.section(QLatin1Char('_'), 0, 0),
                kPostalInterface, QStringLiteral("Post"));
    call << id << QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact));
    if (!QDBusConnection::sessionBus().send(call))
        qWarning() << "Notifier: could not post notification";
}
