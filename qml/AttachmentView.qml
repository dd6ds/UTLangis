import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A non-image attachment inside a message bubble (images are shown by
// ImageGroup): audio (voice messages) as a small player, a video as a tile
// that opens the player, anything else as its file name, which hands the
// file to another app to open or save it.
Item {
    id: view
    property var app
    property string path
    property string contentType
    property color textColor
    // The message, for reacting and replying from the video player.
    property var message: null

    signal pressAndHeld()

    readonly property bool isAudio: contentType.indexOf("audio/") === 0
    readonly property bool isVideo: contentType.indexOf("video/") === 0
    readonly property bool playing: Voice.playingPath === path

    implicitWidth: isAudio ? player.implicitWidth
                           : isVideo ? videoTile.implicitWidth : fileRow.implicitWidth
    implicitHeight: isAudio ? player.implicitHeight
                            : isVideo ? videoTile.implicitHeight : fileRow.implicitHeight

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
        AppLabel {
            text: view.playing ? view.app.durationText(Voice.positionMs) : "🎤"
            color: view.textColor
            font.pixelSize: view.app.fontSecondary
        }
    }

    Rectangle {
        id: videoTile
        visible: view.isVideo
        implicitWidth: view.app.gu * 24
        implicitHeight: view.app.gu * 15
        width: Math.min(implicitWidth, view.width > 0 ? view.width : implicitWidth)
        radius: view.app.gu
        color: "#000000"

        AppLabel {
            anchors.centerIn: parent
            text: "▶"
            color: "#ffffff"
            font.pixelSize: view.app.fontTitle * 2
        }
        AppLabel {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: view.app.gu
            text: "🎬 " + qsTr("Video")
            color: "#ffffff"
            font.pixelSize: view.app.fontSecondary
        }
        MouseArea {
            anchors.fill: parent
            Accessible.name: qsTr("Play video")
            onClicked: view.app.openVideo(view.path, view.contentType, view.message)
            onPressAndHold: view.pressAndHeld()
        }
    }

    RowLayout {
        id: fileRow
        visible: !view.isAudio && !view.isVideo
        width: view.width
        spacing: view.app.gu

        AppLabel {
            Layout.fillWidth: true
            text: "📄 " + view.path.split("/").pop()
            color: view.textColor
            elide: Text.ElideMiddle
        }
        ToolButton {
            text: "⤓"
            font.pixelSize: view.app.fontTitle
            palette.buttonText: view.textColor
            Accessible.name: qsTr("Open or save with another app")
            onClicked: view.app.exportFile(view.path, view.contentType)
        }
    }
}
