import QtQuick 2.12
import QtQuick.Controls 2.12

// The images of a message on a black full-screen page, starting at the one
// that was tapped. Swipe left/right to go through them (only while the
// current image is not zoomed in, so a zoomed image can be moved around);
// each image can be zoomed (ZoomableImage). The ✕ button returns to the chat,
// ✂ crops the image shown and puts the result into the chat for sending.
Page {
    id: page
    property var app
    // Local file paths of the images, in the order of the message.
    property var paths: []
    property int startIndex: 0
    // The message of the images, for reacting and replying (may be null).
    property var message: null

    background: Rectangle { color: "#000000" }

    // A horizontal list that snaps to one image at a time. It creates only
    // the images in view and next to it, so large albums stay light.
    ListView {
        id: images
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: page.paths
        interactive: !(currentItem && currentItem.zoom > 1)

        delegate: ZoomableImage {
            width: images.width
            height: images.height
            path: modelData

            // An image swiped away is shown unzoomed when it comes back.
            readonly property bool current: ListView.isCurrentItem
            onCurrentChanged: {
                if (!current)
                    reset()
            }
        }

        Component.onCompleted: {
            currentIndex = page.startIndex
            positionViewAtIndex(page.startIndex, ListView.Beginning)
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

    // Crops the image shown; the result waits in the chat to be sent.
    ToolButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: page.app.gu
        text: "✂"
        font.pixelSize: page.app.fontTitle
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("Crop and send")
        onClicked: page.app.openCropper(page.paths[images.currentIndex],
                                        function(url) { page.app.photoToChat(url) })
    }

    // Hands the image shown to another app (gallery, file manager).
    ToolButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: page.app.gu * 7
        anchors.topMargin: page.app.gu
        text: "⤓"
        font.pixelSize: page.app.fontTitle
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("Open or save with another app")
        onClicked: {
            var path = String(page.paths[images.currentIndex])
            var ext = path.split(".").pop().toLowerCase()
            page.app.exportFile(path, ext === "png" ? "image/png" : "image/jpeg")
        }
    }

    // "2 / 11" while a message has several images.
    Label {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: page.app.gu * 2
        visible: page.paths.length > 1
        text: qsTr("%1 / %2").arg(images.currentIndex + 1).arg(page.paths.length)
        color: "#ffffff"
        font.pixelSize: page.app.fontSecondary
        style: Text.Outline
        styleColor: "#000000"
    }

    MediaActionBar {
        id: actionBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: page.message !== null
        app: page.app
        message: page.message
    }

    PageIndicator {
        anchors.bottom: actionBar.visible ? actionBar.top : parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: page.app.gu * 2
        visible: page.paths.length > 1 && page.paths.length <= 12
        count: page.paths.length
        currentIndex: images.currentIndex
        palette.dark: "#ffffff"
    }
}
