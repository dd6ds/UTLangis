#include "imageeditor.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QImage>
#include <QImageReader>
#include <QTransform>
#include <QUrl>

namespace {

// Plain paths and file:// URLs both occur (received attachments, Content Hub).
QString localPath(const QString &url)
{
    const QUrl parsed(url);
    return parsed.isLocalFile() ? parsed.toLocalFile() : url;
}

// Upright, as the QML Image with autoTransform shows it.
QImage load(const QString &url)
{
    QImageReader reader(localPath(url));
    reader.setAutoTransform(true);
    const QImage image = reader.read();
    if (image.isNull())
        qWarning() << "ImageEditor: cannot read" << url << reader.errorString();
    return image;
}

constexpr int kJpegQuality = 92;

} // namespace

ImageEditor::ImageEditor(const QString &workDir, QObject *parent)
    : QObject(parent), m_workDir(workDir)
{
    QDir dir(m_workDir);
    dir.removeRecursively();
    QDir().mkpath(m_workDir);
}

QString ImageEditor::save(const QImage &image)
{
    const QString path = QStringLiteral("%1/edit-%2-%3.jpg")
            .arg(m_workDir)
            .arg(QDateTime::currentMSecsSinceEpoch())
            .arg(++m_counter);
    if (!image.save(path, "JPEG", kJpegQuality)) {
        qWarning() << "ImageEditor: cannot write" << path;
        return QString();
    }
    return QUrl::fromLocalFile(path).toString();
}

QString ImageEditor::rotate(const QString &url, bool clockwise)
{
    const QImage image = load(url);
    if (image.isNull())
        return QString();
    return save(image.transformed(QTransform().rotate(clockwise ? 90 : -90)));
}

QString ImageEditor::crop(const QString &url, qreal x, qreal y, qreal width, qreal height)
{
    const QImage image = load(url);
    if (image.isNull())
        return QString();
    const QRect area = QRect(qRound(x * image.width()), qRound(y * image.height()),
                             qRound(width * image.width()), qRound(height * image.height()))
            .intersected(image.rect());
    if (area.isEmpty())
        return QString();
    return save(image.copy(area));
}
