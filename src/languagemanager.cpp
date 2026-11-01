// UI language selection, see languagemanager.h.

#include "languagemanager.h"

#include <QCoreApplication>
#include <QDebug>
#include <QLibraryInfo>
#include <QLocale>
#include <QQmlEngine>
#include <QSettings>

namespace {

const QString kSettingsKey = QStringLiteral("language");
const QString kSourceLanguage = QStringLiteral("en");

struct Language {
    const char *code;       // matches i18n/utlangis_<code>.ts (none for English)
    const char *nativeName; // shown untranslated, so everyone finds their own
};

const Language kLanguages[] = {
    { "en", "English" },
    { "de", "Deutsch" },
    { "fr", "Français" },
    { "es", "Español" },
    { "it", "Italiano" },
};

bool isKnown(const QString &code)
{
    for (const Language &language : kLanguages) {
        if (code == QLatin1String(language.code))
            return true;
    }
    return false;
}

} // namespace

LanguageManager::LanguageManager(QQmlEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine)
{
    const QString stored = QSettings().value(kSettingsKey).toString();
    m_language = isKnown(stored) ? stored : QString();
    applyTranslation();
}

void LanguageManager::setLanguage(const QString &code)
{
    const QString language = isKnown(code) ? code : QString();
    if (language == m_language)
        return;
    m_language = language;
    QSettings().setValue(kSettingsKey, m_language);
    applyTranslation();
    m_engine->retranslate();
    emit languageChanged();
}

QString LanguageManager::effectiveLanguage() const
{
    if (!m_language.isEmpty())
        return m_language;
    // QLocale::system() reads LANG/LANGUAGE, which Lomiri sets from the
    // phone's language setting.
    const QString system = QLocale::system().name().left(2);
    return isKnown(system) ? system : kSourceLanguage;
}

QVariantList LanguageManager::uiLanguages() const
{
    QVariantList list;
    for (const Language &language : kLanguages) {
        list.append(QVariantMap{
            { QStringLiteral("code"), QString::fromLatin1(language.code) },
            { QStringLiteral("name"), QString::fromUtf8(language.nativeName) } });
    }
    return list;
}

// English is the source language: it has no translation file, and a text
// missing from a translation stays English.
void LanguageManager::applyTranslation()
{
    QCoreApplication::removeTranslator(&m_appTranslator);
    QCoreApplication::removeTranslator(&m_qtTranslator);
    const QString code = effectiveLanguage();
    if (m_appTranslator.load(QStringLiteral(":/i18n/utlangis_") + code))
        QCoreApplication::installTranslator(&m_appTranslator);
    // Qt's own texts (dialog buttons), if the phone has them installed.
    if (m_qtTranslator.load(QStringLiteral("qtbase_") + code,
                            QLibraryInfo::location(QLibraryInfo::TranslationsPath)))
        QCoreApplication::installTranslator(&m_qtTranslator);
    qDebug() << "LanguageManager:" << code << (m_language.isEmpty() ? "(phone)" : "(chosen)");
}
