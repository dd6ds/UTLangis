import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Settings: the registered number, the profile name, notifications, read
// receipts, the language and the light/dark appearance, plus a note on
// running in the background.
Page {
    id: page
    property var app

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: qsTr("Settings")
        onBack: page.app.stack.pop()
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 2 * page.app.spacingUnit
        clip: true

        ColumnLayout {
            id: content
            x: page.app.spacingUnit
            y: page.app.spacingUnit
            // The page, not the Flickable's content item, whose size follows
            // the content.
            width: page.width - 2 * page.app.spacingUnit
            spacing: page.app.spacingUnit * 1.5

            AppLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("Registered number: %1").arg(Signal.phone)
            }

            AppLabel {
                Layout.fillWidth: true
                visible: Signal.linked
                wrapMode: Text.Wrap
                color: page.app.colorSecondaryText
                font.pixelSize: page.app.fontSecondary
                text: qsTr("This phone is a linked device. The profile is managed on the "
                           + "phone the account was registered with.")
            }

            Button {
                Layout.fillWidth: true
                visible: !Signal.linked
                text: qsTr("Change profile name")
                onClicked: profileDialog.open()
            }

            Button {
                Layout.fillWidth: true
                visible: !Signal.linked
                text: qsTr("Linked devices (e.g. Signal Desktop)")
                onClicked: page.app.stack.push(Qt.resolvedUrl("LinkedDevicesPage.qml"),
                                               { app: page.app })
            }

            Switch {
                id: shutterSwitch
                Layout.fillWidth: true
                text: qsTr("Camera sound (photos in the chat, QR codes)")
                checked: page.app.settings.shutterSound
                onToggled: page.app.settings.shutterSound = checked
                contentItem: AppLabel {
                    leftPadding: shutterSwitch.indicator.width + shutterSwitch.spacing
                    text: shutterSwitch.text
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Switch {
                id: notifySwitch
                Layout.fillWidth: true
                text: qsTr("Notifications")
                checked: Notifications.enabled
                onToggled: Notifications.enabled = checked
                contentItem: AppLabel {
                    leftPadding: notifySwitch.indicator.width + notifySwitch.spacing
                    text: notifySwitch.text
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            GainSlider {
                Layout.fillWidth: true
                app: page.app
                title: qsTr("Microphone gain (voice messages and calls)")
                from: Voice.micGainMinDb
                to: Voice.micGainMaxDb
                value: Voice.micGainDb
                onValueRequested: Voice.micGainDb = value
            }

            GainSlider {
                Layout.fillWidth: true
                app: page.app
                title: qsTr("Volume of voice messages")
                from: 0
                to: Voice.playbackGainMaxDb
                value: Voice.playbackGainDb
                onValueRequested: Voice.playbackGainDb = value
            }

            AppLabel {
                text: qsTr("Notification sound")
                font.bold: true
                font.pixelSize: page.app.fontSecondary
                enabled: Notifications.enabled
            }

            // The phone's default sound, silence, or one of the phone's
            // notification sounds (played once when picked).
            ComboBox {
                id: soundBox
                Layout.fillWidth: true
                enabled: Notifications.enabled
                textRole: "name"
                model: [{ name: qsTr("Phone default"), path: "default" },
                        { name: qsTr("No sound"), path: "" }].concat(Notifications.sounds)
                currentIndex: {
                    for (var i = 0; i < model.length; ++i) {
                        if (model[i].path === Notifications.sound)
                            return i
                    }
                    return 0
                }
                onActivated: {
                    Notifications.sound = model[index].path
                    Notifications.preview(model[index].path)
                }
            }

            Switch {
                id: receiptsSwitch
                Layout.fillWidth: true
                text: qsTr("Send read receipts")
                checked: Signal.sendReadReceipts
                onToggled: Signal.sendReadReceipts = checked
                contentItem: AppLabel {
                    leftPadding: receiptsSwitch.indicator.width + receiptsSwitch.spacing
                    text: receiptsSwitch.text
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            LanguageChoice {
                Layout.fillWidth: true
                app: page.app
            }

            AppearanceChoice {
                Layout.fillWidth: true
                app: page.app
            }

            AppLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: page.app.colorSecondaryText
                font.pixelSize: page.app.fontSecondary
                text: qsTr("Ubuntu Touch pauses apps in the background, so new messages "
                           + "arrive when UT Langis is open. To be notified while it is in "
                           + "the background, prevent app suspension for UT Langis "
                           + "(e.g. with UT Tweak Tool).")
            }
        }
    }

    ProfileDialog {
        id: profileDialog
        app: page.app
    }
}
