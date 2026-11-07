import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12
import QtMultimedia 5.12

// Camera viewfinder for the QR code another device shows when it is to be
// linked to this account (Signal Desktop: "Link new device"). A photo is
// taken every few seconds (or on tap) and searched for the code; once found,
// the user confirms and the device is linked.
Page {
    id: page
    property var app
    // Photo being looked at by the backend; no new one until it answers.
    property bool scanning: false
    property string found: ""
    readonly property int scanIntervalMs: 1500
    readonly property int silentIntervalMs: 700

    background: Rectangle { color: "black" }

    Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        focus.focusMode: Camera.FocusContinuous
        flash.mode: Camera.FlashOff
        // Short exposures: a code on a screen gets blurred by the slightest
        // movement of the hand.
        exposure.exposureMode: Camera.ExposureSports

        imageCapture.onImageSaved: Signal.scanQr(path)
        imageCapture.onCaptureFailed: page.scanning = false
        onError: page.app.showNote(qsTr("The camera is not available: %1").arg(errorString))
    }

    // With the camera sound on, real photos (sharper, but Ubuntu Touch's
    // camera always clicks for them); with it off, silent grabs of the
    // viewfinder picture.
    function takePhoto() {
        if (page.scanning || page.found !== "")
            return
        if (page.app.settings.shutterSound) {
            if (!camera.imageCapture.ready)
                return
            page.scanning = true
            camera.imageCapture.setMetadata("Orientation",
                                            Screen.angleBetween(Screen.orientation,
                                                                Screen.primaryOrientation))
            camera.imageCapture.captureToLocation(Signal.qrPhotoPath())
        } else {
            page.scanning = true
            if (!viewfinder.grabToImage(function(result) {
                    var path = Signal.qrPhotoPath()
                    if (result.saveToFile(path))
                        Signal.scanQr(path)
                    else
                        page.scanning = false
                }))
                page.scanning = false
        }
    }

    Timer {
        interval: page.app.settings.shutterSound ? page.scanIntervalMs : page.silentIntervalMs
        repeat: true
        running: page.visible && page.found === "" && !Signal.busy
        onTriggered: page.takePhoto()
    }

    Connections {
        target: Signal
        onQrScanned: {
            page.scanning = false
            if (page.found !== "")
                return
            page.found = text
            confirmDialog.open()
        }
        onQrNotFound: page.scanning = false
        onDeviceLinked: {
            page.app.showNote(qsTr("The device was linked."))
            page.app.stack.pop()
        }
        onErrorOccurred: {
            if (action === "linkDevice" || action === "scanQr") {
                page.scanning = false
                page.found = ""
            }
        }
    }

    VideoOutput {
        id: viewfinder
        anchors.fill: parent
        source: camera
        autoOrientation: true
        fillMode: VideoOutput.PreserveAspectFit

        MouseArea {
            anchors.fill: parent
            onClicked: {
                camera.focus.customFocusPoint = viewfinder.mapPointToSourceNormalized(
                            Qt.point(mouse.x, mouse.y))
                camera.focus.focusPointMode = Camera.FocusPointCustom
                camera.searchAndLock()
                page.takePhoto()
            }
        }
    }

    // Frame to aim with.
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.7
        height: width
        color: "transparent"
        radius: page.app.gu
        border.color: "#ffffff"
        border.width: page.app.gu * 0.4
        opacity: 0.8
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

    AppLabel {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: page.app.gu * 6
        width: parent.width * 0.85
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: "#ffffff"
        style: Text.Outline
        styleColor: "#80000000"
        text: Signal.busy ? qsTr("Linking the device …")
                          : qsTr("Point the camera at the QR code shown by Signal Desktop "
                                 + "(\"Link new device\").") + "\n"
                            + qsTr("Hold the phone still, with the code filling the white frame.")
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: Signal.busy
        visible: running
    }

    Dialog {
        id: confirmDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: parent.width * 0.9
        modal: true
        title: qsTr("Link device?")
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: Signal.linkDevice(page.found)
        onRejected: page.found = ""

        contentItem: AppLabel {
            wrapMode: Text.Wrap
            text: qsTr("The other device will be able to read and send your messages. "
                       + "Only link devices that belong to you.")
        }
    }
}
