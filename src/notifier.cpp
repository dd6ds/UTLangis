// Posts notification cards to com.lomiri.Postal, see notifier.h.

#include "notifier.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

const QString kPostalService = QStringLiteral("com.lomiri.Postal");
const QString kPostalPathPrefix = QStringLiteral("/com/lomiri/Postal/");
const QString kPostalInterface = QStringLiteral("com.lomiri.Postal");
// Used when not started by lomiri-app-launch (desktop test runs).
const QString kFallbackAppId = QStringLiteral("ubsignal_ubsignal");

} // namespace

// Postal wants "<package>_<app>"; APP_ID also carries the version.
QString Notifier::appId()
{
    const QStringList parts = qEnvironmentVariable("APP_ID").split(QLatin1Char('_'));
    if (parts.size() < 2)
        return kFallbackAppId;
    return parts.at(0) + QLatin1Char('_') + parts.at(1);
}

void Notifier::notify(const QString &title, const QString &sender, const QString &text) const
{
    QString body = text.isEmpty() ? QCoreApplication::translate("Notifier", "Attachment")
                                  : text;
    if (!sender.isEmpty() && sender != title)
        body = sender + QStringLiteral(": ") + body;
    const QString summary = title.isEmpty()
            ? QCoreApplication::translate("Notifier", "New message") : title;

    const QJsonObject card{{QStringLiteral("summary"), summary},
                           {QStringLiteral("body"), body},
                           {QStringLiteral("popup"), true},
                           {QStringLiteral("persist"), true}};
    const QJsonObject notification{{QStringLiteral("card"), card},
                                   {QStringLiteral("sound"), true},
                                   {QStringLiteral("vibrate"), true}};
    const QJsonObject message{{QStringLiteral("notification"), notification}};

    const QString id = appId();
    // The object path is the package name; ubsignal has no characters that
    // would need D-Bus escaping.
    QDBusMessage call = QDBusMessage::createMethodCall(
                kPostalService, kPostalPathPrefix + id.section(QLatin1Char('_'), 0, 0),
                kPostalInterface, QStringLiteral("Post"));
    call << id << QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact));
    if (!QDBusConnection::sessionBus().send(call))
        qWarning() << "Notifier: could not post notification";
}
