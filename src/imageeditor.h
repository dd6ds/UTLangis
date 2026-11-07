#pragma once

#include <QObject>
#include <QString>

class QImage;

// Turns and crops photos for the crop page (qml/CropPage.qml): received
// images and photos about to be sent. Every step writes a new JPEG file into
// the work folder and returns its file:// URL; the original stays untouched.
// The work folder is emptied at start, its files are only needed until sent.
class ImageEditor : public QObject
{
    Q_OBJECT

public:
    explicit ImageEditor(const QString &workDir, QObject *parent = nullptr);

    // The image turned by 90° (clockwise when `clockwise`), or "" on error.
    Q_INVOKABLE QString rotate(const QString &url, bool clockwise);
    // The part of the image given in fractions (0..1) of its width and height,
    // as shown upright (EXIF orientation applied), or "" on error.
    Q_INVOKABLE QString crop(const QString &url, qreal x, qreal y, qreal width, qreal height);

private:
    QString save(const QImage &image);

    QString m_workDir;
    int m_counter = 0;
};
