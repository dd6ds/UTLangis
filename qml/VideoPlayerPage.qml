import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtMultimedia 5.12

// A received video, full screen: tap to show or hide the controls (play /
// pause, position), ⤓ hands it to another app to open or save it.
Page {
    id: page
    property var app
    // Local path and MIME type of the video file.
    property string path: ""
    property string contentType: "video/mp4"
    property bool controlsShown: true
    // The message of the video, for reacting and replying (may be null).
    property var message: null

    background: Rectangle { color: "#000000" }

    Video {
        id: video
        anchors.fill: parent
        source: "file://" + page.path
        fillMode: VideoOutput.PreserveAspectFit
        autoPlay: true
        onStopped: page.controlsShown = true
        onErrorChanged: {
            if (error !== MediaPlayer.NoError)
                page.app.showNote(qsTr("The video cannot be played: %1").arg(errorString))
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: page.controlsShown = !page.controlsShown
    }

    ToolButton {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: page.app.gu
        visible: page.controlsShown
        text: "✕"
        font.pixelSize: page.app.fontTitle
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("Close")
        onClicked: {
            video.stop()
            page.app.stack.pop()
        }
    }

    ToolButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: page.app.gu
        visible: page.controlsShown
        text: "⤓"
        font.pixelSize: page.app.fontTitle
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("Open or save with another app")
        onClicked: {
            video.pause()
            page.app.exportFile(page.path, page.contentType)
        }
    }

    MediaActionBar {
        id: actionBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: page.message !== null && page.controlsShown
        app: page.app
        message: page.message
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actionBar.visible ? actionBar.top : parent.bottom
        height: controls.implicitHeight + 2 * page.app.gu
        visible: page.controlsShown
        color: "#99000000"

        RowLayout {
            id: controls
            anchors.fill: parent
            anchors.margins: page.app.gu
            spacing: page.app.gu

            ToolButton {
                text: video.playbackState === MediaPlayer.PlayingState ? "❚❚" : "▶"
                font.pixelSize: page.app.fontTitle
                palette.buttonText: "#ffffff"
                Accessible.name: video.playbackState === MediaPlayer.PlayingState
                                 ? qsTr("Pause") : qsTr("Play")
                onClicked: {
                    if (video.playbackState === MediaPlayer.PlayingState)
                        video.pause()
                    else
                        video.play()
                }
            }
            Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, video.duration)
                value: video.position
                enabled: video.seekable
                onMoved: video.seek(value)
            }
            AppLabel {
                color: "#ffffff"
                font.pixelSize: page.app.fontSecondary
                text: page.app.durationText(video.position) + " / "
                      + page.app.durationText(video.duration)
            }
        }
    }
}
