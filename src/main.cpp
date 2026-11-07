// Entry point: sets up the QML engine, starts the Signal backend
// (SignalClient) and exposes it, the UI language (LanguageManager), voice
// messages (VoiceNotes) and the phone's light/dark theme (SystemTheme) to QML.

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QtQml>
#include <QtWebEngine>

#include "languagemanager.h"
#include "callengine.h"
#include "imageeditor.h"
#include "remotevideo.h"
#include "signalclient.h"
#include "systemtheme.h"
#include "voicenotes.h"

// Confined click apps may only write below ~/.local/share/<package-name>
// (and the matching cache/config dirs). The Signal database, the keys and
// the attachments live there.
static QString dataDir()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/utlangis");
    QDir().mkpath(dir);
    return dir;
}

// Ubuntu Touch exports GRID_UNIT_PX (typically 18-27 on a phone, 8 on a
// desktop). All QML sizes are multiples of it.
static int gridUnitPx()
{
    bool ok = false;
    const int px = qEnvironmentVariableIntValue("GRID_UNIT_PX", &ok);
    return (ok && px > 0) ? px : 8;
}

static SignalClient *exposeBackend(QQmlApplicationEngine &engine)
{
    // Owned by the engine so it outlives every QML binding during shutdown.
    auto *notifier = new Notifier(&engine);
    auto *client = new SignalClient(dataDir(), notifier, &engine);
    engine.rootContext()->setContextProperty(QStringLiteral("Notifications"), notifier);
    qmlRegisterUncreatableType<ThreadListModel>(
        "UTLangis", 1, 0, "ThreadListModel", QStringLiteral("Provided by Signal.threads"));
    qmlRegisterUncreatableType<MessageListModel>(
        "UTLangis", 1, 0, "MessageListModel", QStringLiteral("Provided by Signal.messages"));
    engine.rootContext()->setContextProperty(QStringLiteral("Signal"), client);
    auto *calls = new CallEngine(client, &engine);
    engine.rootContext()->setContextProperty(QStringLiteral("Calls"), calls);
    RemoteVideo::engine = calls;
    qmlRegisterType<RemoteVideo>("UTLangis", 1, 0, "RemoteVideo");
    // Installs the translation before the first page is created.
    engine.rootContext()->setContextProperty(QStringLiteral("Language"),
                                             new LanguageManager(&engine, &engine));
    // Recordings wait in the app's cache dir until the backend has sent them.
    const QString recordDir = QStandardPaths::writableLocation(
            QStandardPaths::GenericCacheLocation) + QStringLiteral("/utlangis/voice");
    engine.rootContext()->setContextProperty(QStringLiteral("Voice"),
                                             new VoiceNotes(recordDir, &engine));
    // Turned and cropped photos wait there until they are sent.
    engine.rootContext()->setContextProperty(
            QStringLiteral("ImageEditor"),
            new ImageEditor(QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
                                    + QStringLiteral("/utlangis/edited"),
                            &engine));
    engine.rootContext()->setContextProperty(QStringLiteral("SystemTheme"),
                                             new SystemTheme(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("gridUnitPx"), gridUnitPx());
    return client;
}

int main(int argc, char *argv[])
{
    // The platform style brings its own palette; the app sets all colours
    // itself (main.qml), which needs the Default style.
    qputenv("QT_QUICK_CONTROLS_STYLE", "Default");

    QGuiApplication app(argc, argv);
    // Shares the OpenGL context the captcha page's web view needs; must come
    // before the first Qt Quick window.
    QtWebEngine::initialize();
    app.setApplicationName(QStringLiteral("UTLangis"));
    app.setOrganizationName(QStringLiteral("utlangis"));

    QQmlApplicationEngine engine;
    SignalClient *client = exposeBackend(engine);

    // Lomiri suspends background apps, which kills the message connection
    // without the backend noticing. Reopen it when the app is shown again.
    QObject::connect(&app, &QGuiApplication::applicationStateChanged, client,
                     [client](Qt::ApplicationState state) {
                         if (state == Qt::ApplicationActive)
                             client->reconnect();
                     });

    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qWarning() << "UT Langis: failed to load QML";
        return -1;
    }
    return app.exec();
}
