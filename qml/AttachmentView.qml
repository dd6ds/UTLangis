import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// An attachment inside a message bubble: images inline (tap opens them full
// screen), audio (voice messages) as a small player, anything else as its
// file name.
Item {
    id: view
    property var app
    property string path
    property string contentType
    property color textColor

    // Press and hold on an image (the bubble's own handler is underneath).
    signal pressAndHeld()

    readonly property bool isImage: contentType.indexOf("image/") === 0
    readonly property bool isAudio: contentType.indexOf("audio/") === 0
    readonly property bool playing: Voice.playingPath === path

    implicitWidth: isImage ? image.implicitWidth
                           : isAudio ? player.implicitWidth : fileLabel.implicitWidth
    implicitHeight: isImage ? image.implicitHeight
                            : isAudio ? player.implicitHeight : fileLabel.implicitHeight

    Image {
        id: image
        visible: view.isImage
        width: Math.min(implicitWidth, view.width)
        source: view.isImage ? "file://" + view.path : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: view.app.gu * 30
        autoTransform: true

        MouseArea {
            anchors.fill: parent
            onClicked: view.app.openImage(view.path)
            onPressAndHold: view.pressAndHeld()
        }
    }

    RowLayout {
        id: player
        visible: view.isAudio
        width: view.width
        spacing: view.app.gu

        ToolButton {
            text: view.playing ? "■" : "▶"
            font.pixelSize: view.app.fontTitle
            palette.buttonText: view.textColor
            Accessible.name: view.playing ? qsTr("Stop") : qsTr("Play voice message")
            onClicked: Voice.togglePlay(view.path)
        }
        ProgressBar {
            Layout.preferredWidth: view.app.gu * 12
            Layout.fillWidth: true
            from: 0
            to: Math.max(1, Voice.durationMs)
            value: view.playing ? Voice.positionMs : 0
        }
        Label {
            text: view.playing ? view.app.durationText(Voice.positionMs) : "🎤"
            color: view.textColor
            font.pixelSize: view.app.fontSecondary
        }
    }

    Label {
        id: fileLabel
        visible: !view.isImage && !view.isAudio
        width: view.width
        text: "📄 " + view.path.split("/").pop()
        color: view.textColor
        elide: Text.ElideMiddle
    }
}
