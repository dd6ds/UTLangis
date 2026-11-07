import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// The devices of this account (this phone and linked ones such as Signal
// Desktop): link a new one by its QR code, or unlink one.
Page {
    id: page
    property var app
    property var unlinking: null

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: qsTr("Linked devices")
        onBack: page.app.stack.pop()
    }

    Component.onCompleted: Signal.refreshDevices()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: page.app.spacingUnit
        spacing: page.app.spacingUnit

        Button {
            Layout.fillWidth: true
            text: qsTr("Link new device (scan QR code)")
            onClicked: page.app.stack.push(Qt.resolvedUrl("ScanQrPage.qml"), { app: page.app })
        }

        AppLabel {
            Layout.fillWidth: true
            visible: Signal.devices.length === 0
            wrapMode: Text.Wrap
            color: page.app.colorSecondaryText
            text: qsTr("Loading …")
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Signal.devices
            spacing: page.app.gu

            delegate: Rectangle {
                width: ListView.view.width
                height: row.implicitHeight + page.app.spacingUnit
                radius: page.app.gu
                color: page.app.colorSurface

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.margins: page.app.spacingUnit / 2
                    anchors.leftMargin: page.app.spacingUnit

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        AppLabel {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.bold: true
                            text: modelData.self ? qsTr("This phone")
                                  : (modelData.name !== "" ? modelData.name
                                                           : qsTr("Device %1").arg(modelData.id))
                        }
                        AppLabel {
                            Layout.fillWidth: true
                            color: page.app.colorSecondaryText
                            font.pixelSize: page.app.fontSecondary
                            text: qsTr("Last active: %1").arg(
                                      new Date(modelData.lastSeen).toLocaleDateString())
                        }
                    }

                    Button {
                        visible: !modelData.self
                        text: qsTr("Unlink")
                        onClicked: {
                            page.unlinking = modelData
                            unlinkDialog.open()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: unlinkDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: parent.width * 0.9
        modal: true
        title: qsTr("Unlink device?")
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: Signal.unlinkDevice(page.unlinking.id)

        contentItem: AppLabel {
            wrapMode: Text.Wrap
            text: qsTr("The device will no longer receive or send your messages.")
        }
    }
}
