// Entry point: sets up translations and the QML engine, starts the Signal
// backend (SignalClient) and exposes it and the phone's light/dark theme
// (SystemTheme) to QML.

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QLibraryInfo>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QTranslator>
#include <QtQml>
#include <QtWebEngine>

#include "signalclient.h"
#include "systemtheme.h"

// Confined click apps may only write below ~/.local/share/<package-name>
// (and the matching cache/config dirs). The Signal database, the keys and
// the attachments live there.
static QString dataDir()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/ubsignal");
    QDir().mkpath(dir);
    return dir;
}

// Follows the language selected on the phone. App texts are embedded as
// :/i18n/ubsignal_<lang>.qm; English is the source language.
static void installTranslators(QGuiApplication &app)
{
    const QLocale locale = QLocale::system();
    auto *appTranslator = new QTranslator(&app);
    if (appTranslator->load(locale, QStringLiteral("ubsignal"), QStringLiteral("_"),
                            QStringLiteral(":/i18n")))
        app.installTranslator(appTranslator);
    auto *qtTranslator = new QTranslator(&app);
    if (qtTranslator->load(locale, QStringLiteral("qtbase"), QStringLiteral("_"),
                           QLibraryInfo::location(QLibraryInfo::TranslationsPath)))
        app.installTranslator(qtTranslator);
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
    auto *client = new SignalClient(dataDir(), &engine);
    qmlRegisterUncreatableType<ThreadListModel>(
        "ubSignal", 1, 0, "ThreadListModel", QStringLiteral("Provided by Signal.threads"));
    qmlRegisterUncreatableType<MessageListModel>(
        "ubSignal", 1, 0, "MessageListModel", QStringLiteral("Provided by Signal.messages"));
    engine.rootContext()->setContextProperty(QStringLiteral("Signal"), client);
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
    app.setApplicationName(QStringLiteral("ubSignal"));
    app.setOrganizationName(QStringLiteral("ubsignal"));
    installTranslators(app);

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
        qWarning() << "ubSignal: failed to load QML";
        return -1;
    }
    return app.exec();
}
