// The other side's video in a call ("RemoteVideo" in QML): draws
// CallEngine's newest picture, filling the item (cropped, not stretched).

#ifndef REMOTEVIDEO_H
#define REMOTEVIDEO_H

#include <QQuickPaintedItem>

class CallEngine;

class RemoteVideo : public QQuickPaintedItem
{
    Q_OBJECT

public:
    explicit RemoteVideo(QQuickItem *parent = nullptr);

    void paint(QPainter *painter) override;

    // Set once in main.cpp, before QML is loaded.
    static CallEngine *engine;
};

#endif
