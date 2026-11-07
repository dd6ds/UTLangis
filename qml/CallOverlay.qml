import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtMultimedia 5.12
import UTLangis 1.0

// Full-screen call view while a call is set up or running: who, how long,
// and the buttons (camera, microphone, loudspeaker, hang up). In a video
// call the other side's picture fills the screen and our camera picture is
// shown small in a corner. Ringing calls are shown by IncomingCallDialog
// until they are answered.
Rectangle {
    id: overlay
    property var app

    readonly property bool active: Calls.state !== "" && Calls.state !== "incoming"
    readonly property bool showRemote: Calls.remoteVideo && Calls.state === "connected"
    // Pictures per second sent from our camera.
    readonly property int cameraFps: 12

    visible: active
    color: app.darkMode ? "#101820" : "#1b2b45"

    function statusText() {
        switch (Calls.state) {
        case "outgoing":
            return qsTr("Calling …")
        case "ringing":
            return qsTr("Ringing …")
        case "connecting":
            return qsTr("Connecting …")
        case "connected":
            return overlay.app.durationText(Calls.seconds * 1000)
        case "ended":
            return qsTr("Call ended")
        default:
            return ""
        }
    }

    // Keeps touches from reaching the pages below.
    MouseArea {
        anchors.fill: parent
    }

    RemoteVideo {
        anchors.fill: parent
        visible: overlay.showRemote
    }

    // --- Our camera ---------------------------------------------------------
    Camera {
        id: camera
        position: Camera.FrontFace
        captureMode: Camera.CaptureViewfinder
        cameraState: overlay.active && Calls.camera && Calls.state !== "ended"
                     ? Camera.ActiveState : Camera.UnloadedState
    }

    Rectangle {
        id: selfView
        visible: overlay.active && Calls.camera
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: overlay.app.gu * 2
        width: overlay.width * 0.3
        height: width * 4 / 3
        radius: overlay.app.gu
        color: "#000000"
        clip: true

        VideoOutput {
            id: viewfinder
            anchors.fill: parent
            source: camera
            autoOrientation: true
            fillMode: VideoOutput.PreserveAspectCrop
        }
    }

    // The camera picture reaches WebRTC as grabs of the viewfinder: the
    // phone's camera gives its pictures to the screen only.
    Timer {
        interval: 1000 / overlay.cameraFps
        repeat: true
        running: selfView.visible && camera.cameraStatus === Camera.ActiveStatus
                 && (Calls.state === "connected" || Calls.state === "connecting"
                     || Calls.state === "ringing" || Calls.state === "outgoing")
        onTriggered: viewfinder.grabToImage(function(result) { Calls.pushFrame(result.image) },
                                            Qt.size(360, 480))
    }

    // --- Who and how long -----------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        // Below the picture of the other side, else a bit above the middle.
        anchors.verticalCenterOffset: overlay.height * (overlay.showRemote ? 0.3 : -0.12)
        width: parent.width - 4 * overlay.app.spacingUnit
        spacing: overlay.app.spacingUnit

        Avatar {
            Layout.alignment: Qt.AlignHCenter
            visible: !overlay.showRemote
            app: overlay.app
            size: overlay.app.gu * 14
            name: Calls.title
            colorKey: Calls.thread
        }
        AppLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Calls.title.length ? Calls.title : qsTr("Unknown contact")
            color: "#ffffff"
            style: Text.Outline
            styleColor: "#60000000"
            font.pixelSize: overlay.app.fontTitle * (overlay.showRemote ? 1.0 : 1.3)
            font.weight: Font.DemiBold
        }
        AppLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: overlay.statusText()
            color: "#e0e6ee"
            style: Text.Outline
            styleColor: "#60000000"
            font.pixelSize: overlay.app.fontBody
        }
    }

    // --- Buttons -------------------------------------------------------------
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: overlay.app.gu * 8
        spacing: overlay.app.gu * 3

        RoundButton {
            implicitWidth: overlay.app.gu * 7.5
            implicitHeight: implicitWidth
            enabled: Calls.state !== "ended"
            text: "🎥"
            font.pixelSize: overlay.app.fontTitle * 1.2
            Accessible.name: Calls.camera ? qsTr("Camera off") : qsTr("Camera on")
            background: Rectangle {
                radius: width / 2
                color: Calls.camera ? "#ffffff" : "#40ffffff"
            }
            onClicked: Calls.setCamera(!Calls.camera)
        }

        RoundButton {
            implicitWidth: overlay.app.gu * 7.5
            implicitHeight: implicitWidth
            enabled: Calls.state !== "ended"
            text: Calls.muted ? "🔇" : "🎤"
            font.pixelSize: overlay.app.fontTitle * 1.2
            Accessible.name: Calls.muted ? qsTr("Microphone off") : qsTr("Microphone on")
            background: Rectangle {
                radius: width / 2
                color: Calls.muted ? "#ffffff" : "#40ffffff"
            }
            onClicked: Calls.setMuted(!Calls.muted)
        }

        RoundButton {
            implicitWidth: overlay.app.gu * 7.5
            implicitHeight: implicitWidth
            enabled: Calls.state !== "ended"
            text: Calls.speaker ? "🔊" : "🔈"
            font.pixelSize: overlay.app.fontTitle * 1.2
            Accessible.name: Calls.speaker ? qsTr("Loudspeaker on") : qsTr("Loudspeaker off")
            background: Rectangle {
                radius: width / 2
                color: Calls.speaker ? "#ffffff" : "#40ffffff"
            }
            onClicked: Calls.setSpeaker(!Calls.speaker)
        }

        RoundButton {
            id: hangupButton
            implicitWidth: overlay.app.gu * 7.5
            implicitHeight: implicitWidth
            enabled: Calls.state !== "ended"
            text: "✆"
            font.pixelSize: overlay.app.fontTitle * 1.4
            palette.buttonText: "#ffffff"
            Accessible.name: qsTr("Hang up")
            background: Rectangle {
                radius: width / 2
                color: hangupButton.down ? Qt.darker("#e53935", 1.2) : "#e53935"
            }
            onClicked: Calls.hangup()
        }
    }
}
