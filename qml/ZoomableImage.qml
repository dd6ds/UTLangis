import QtQuick 2.12
import QtQuick.Controls 2.12

// One image filling its area on black, for ImageViewerPage. Pinch to zoom
// (up to maxZoom times the fitted size), drag to move, double-tap to zoom
// in at that spot or back out.
Item {
    id: view
    property string path

    readonly property real maxZoom: 5
    readonly property real doubleTapZoom: 2.5
    readonly property real zoom: flick.width > 0 ? flick.contentWidth / flick.width : 1

    // Sets the zoom factor (relative to the fitted size), keeping `center`
    // (in content coordinates) under the finger.
    function zoomTo(factor, center) {
        var clamped = Math.max(1, Math.min(view.maxZoom, factor))
        flick.resizeContent(flick.width * clamped, flick.height * clamped, center)
        flick.returnToBounds()
    }

    function reset() {
        zoomTo(1, Qt.point(0, 0))
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // The fitted size follows the page, e.g. when the phone is turned.
        onWidthChanged: view.reset()
        onHeightChanged: view.reset()

        PinchArea {
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)

            property real startZoom: 1

            onPinchStarted: startZoom = view.zoom
            onPinchUpdated: {
                flick.contentX += pinch.previousCenter.x - pinch.center.x
                flick.contentY += pinch.previousCenter.y - pinch.center.y
                var factor = Math.max(1, Math.min(view.maxZoom, startZoom * pinch.scale))
                flick.resizeContent(flick.width * factor, flick.height * factor, pinch.center)
            }
            onPinchFinished: flick.returnToBounds()

            Image {
                id: image
                width: flick.contentWidth
                height: flick.contentHeight
                source: view.path.length ? "file://" + view.path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                autoTransform: true
                // Enough detail for the largest zoom without loading huge
                // camera photos at full size.
                sourceSize.width: flick.width * view.maxZoom
                sourceSize.height: flick.height * view.maxZoom

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: view.zoomTo(view.zoom > 1 ? 1 : view.doubleTapZoom,
                                                 Qt.point(mouse.x, mouse.y))
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: image.status === Image.Loading
                    visible: running
                }
            }
        }
    }
}
