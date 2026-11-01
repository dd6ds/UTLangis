// User interface language ("Language" in QML). By default the app follows
// the language selected on the phone; the user can pick a fixed one in the
// settings, which is stored and applied immediately (QQmlEngine::retranslate).

#ifndef LANGUAGEMANAGER_H
#define LANGUAGEMANAGER_H

#include <QObject>
#include <QTranslator>
#include <QVariantList>

class QQmlEngine;

class LanguageManager : public QObject
{
    Q_OBJECT
    // "" = like the phone, otherwise a code from uiLanguages ("de", "fr", ...).
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    // [{ code, name }] with each language named in itself.
    Q_PROPERTY(QVariantList uiLanguages READ uiLanguages CONSTANT)

public:
    explicit LanguageManager(QQmlEngine *engine, QObject *parent = nullptr);

    QString language() const { return m_language; }
    void setLanguage(const QString &code);
    QVariantList uiLanguages() const;

signals:
    void languageChanged();

private:
    QString effectiveLanguage() const;
    void applyTranslation();

    QQmlEngine *m_engine;
    QTranslator m_appTranslator;
    QTranslator m_qtTranslator;
    QString m_language;
};

#endif
