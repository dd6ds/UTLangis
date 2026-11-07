import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12
import QtMultimedia 5.12

// Takes a photo for the open chat; it then waits above the input field to
// be sent (or cropped). With the camera sound on, a real photo is taken
// (Ubuntu Touch's camera always clicks for those); with it off, the
// viewfinder picture is saved silently, in screen resolution.
Page {
    id: page
    property var app

    background: Rectangle { color: "#000000" }

    Camera {
        id: camera
        position: Camera.BackFace
        captureMode: Camera.CaptureStillImage
        focus.focusMode: Camera.FocusContinuous

        imageCapture.onImageSaved: page.app.photoToChat("file://" + path)
        imageCapture.onCaptureFailed: page.app.showNote(qsTr("The photo could not be taken."))
        onError: page.app.showNote(qsTr("The camera is not available: %1").arg(errorString))
    }

    function takePhoto() {
        var path = ImageEditor.newPhotoPath()
        if (page.app.settings.shutterSound) {
            if (!camera.imageCapture.ready)
                return
            // Tells the camera service how the phone is held, so the photo
            // is stored upright.
            camera.imageCapture.setMetadata("Orientation",
                                            Screen.angleBetween(Screen.orientation,
                                                                Screen.primaryOrientation))
            camera.imageCapture.captureToLocation(path)
        } else {
            viewfinder.grabToImage(function(result) {
                if (result.saveToFile(path))
                    page.app.photoToChat("file://" + path)
                else
                    page.app.showNote(qsTr("The photo could not be taken."))
            })
        }
    }

    VideoOutput {
        id: viewfinder
        anchors.fill: parent
        source: camera
        autoOrientation: true
        fillMode: VideoOutput.PreserveAspectFit

        // Tap to focus there.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                camera.focus.customFocusPoint = viewfinder.mapPointToSourceNormalized(
                            Qt.point(mouse.x, mouse.y))
                camera.focus.focusPointMode = Camera.FocusPointCustom
                camera.searchAndLock()
            }
        }
    }

    ToolButton {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: page.app.gu
        text: "‹"
        font.pixelSize: page.app.fontTitle * 1.6
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("Back")
        onClicked: page.app.stack.pop()
    }

    ToolButton {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: page.app.gu
        text: page.app.settings.shutterSound ? "🔊" : "🔇"
        font.pixelSize: page.app.fontTitle * 1.3
        Accessible.name: page.app.settings.shutterSound ? qsTr("Turn camera sound off")
                                                        : qsTr("Turn camera sound on")
        onClicked: page.app.settings.shutterSound = !page.app.settings.shutterSound
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: page.app.gu * 14

        RoundButton {
            id: shutter
            anchors.centerIn: parent
            width: page.app.gu * 9
            height: width
            enabled: camera.cameraStatus === Camera.ActiveStatus
            Accessible.name: qsTr("Take photo")
            background: Rectangle {
                radius: width / 2
                color: shutter.down ? "#cccccc" : "#ffffff"
                border.color: page.app.colorAccent
                border.width: page.app.gu * 0.6
                opacity: shutter.enabled ? 1 : 0.5
            }
            onClicked: page.takePhoto()
        }

        ToolButton {
            anchors.verticalCenter: shutter.verticalCenter
            anchors.left: shutter.right
            anchors.leftMargin: page.app.gu * 4
            text: "🔄"
            font.pixelSize: page.app.fontTitle * 1.3
            Accessible.name: qsTr("Switch camera")
            onClicked: camera.position = camera.position === Camera.FrontFace
                       ? Camera.BackFace : Camera.FrontFace
        }
    }
}
