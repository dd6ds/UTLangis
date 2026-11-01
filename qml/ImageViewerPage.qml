import QtQuick 2.12
import QtQuick.Controls 2.12

// A received or sent image on a black full-screen page. Pinch to zoom (up to
// maxZoom times the fitted size), drag to move, double-tap to zoom in at that
// spot or back out. The ✕ button returns to the chat.
Page {
    id: page
    property var app
    // Local file path of the image.
    property string path

    readonly property real maxZoom: 5
    readonly property real doubleTapZoom: 2.5
    readonly property real zoom: flick.width > 0 ? flick.contentWidth / flick.width : 1

    background: Rectangle { color: "#000000" }

    // Sets the zoom factor (relative to the fitted size), keeping `center`
    // (in content coordinates) under the finger.
    function zoomTo(factor, center) {
        var clamped = Math.max(1, Math.min(page.maxZoom, factor))
        flick.resizeContent(flick.width * clamped, flick.height * clamped, center)
        flick.returnToBounds()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // The fitted size follows the page, e.g. when the phone is turned.
        onWidthChanged: page.zoomTo(1, Qt.point(0, 0))
        onHeightChanged: page.zoomTo(1, Qt.point(0, 0))

        PinchArea {
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)

            property real startZoom: 1

            onPinchStarted: startZoom = page.zoom
            onPinchUpdated: {
                flick.contentX += pinch.previousCenter.x - pinch.center.x
                flick.contentY += pinch.previousCenter.y - pinch.center.y
                var factor = Math.max(1, Math.min(page.maxZoom, startZoom * pinch.scale))
                flick.resizeContent(flick.width * factor, flick.height * factor, pinch.center)
            }
            onPinchFinished: flick.returnToBounds()

            Image {
                width: flick.contentWidth
                height: flick.contentHeight
                source: page.path.length ? "file://" + page.path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                autoTransform: true
                // Enough detail for the largest zoom without loading huge
                // camera photos at full size.
                sourceSize.width: flick.width * page.maxZoom
                sourceSize.height: flick.height * page.maxZoom

                MouseArea {
                    anchors.fill: parent
                    onDoubleClicked: page.zoomTo(page.zoom > 1 ? 1 : page.doubleTapZoom,
                                                 Qt.point(mouse.x, mouse.y))
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: parent.status === Image.Loading
                    visible: running
                }
            }
        }
    }

    ToolButton {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: page.app.gu
        text: "✕"
        font.pixelSize: page.app.fontTitle
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("Close")
        onClicked: page.app.stack.pop()
    }
}
