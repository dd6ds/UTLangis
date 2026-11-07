#include "remotevideo.h"

#include <QPainter>

#include "callengine.h"

CallEngine *RemoteVideo::engine = nullptr;

RemoteVideo::RemoteVideo(QQuickItem *parent) : QQuickPaintedItem(parent)
{
    setRenderTarget(QQuickPaintedItem::FramebufferObject);
    if (engine)
        connect(engine, &CallEngine::remoteFrameChanged, this, [this] { update(); });
}

void RemoteVideo::paint(QPainter *painter)
{
    if (!engine)
        return;
    const QImage frame = engine->remoteFrame();
    if (frame.isNull())
        return;
    // Fill the item, cutting off what does not fit.
    const QSizeF scaled = QSizeF(frame.size()).scaled(size(), Qt::KeepAspectRatioByExpanding);
    const QRectF target((width() - scaled.width()) / 2, (height() - scaled.height()) / 2,
                        scaled.width(), scaled.height());
    painter->setRenderHint(QPainter::SmoothPixmapTransform);
    painter->drawImage(target, frame);
}
