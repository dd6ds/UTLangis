import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Sets up Signal on this phone, in one of two ways the user picks:
// - register with a phone number: number and captcha first (CaptchaPage),
//   then the code Signal sends by SMS or call;
// - link as an additional device of an existing account by scanning a QR
//   code with the Signal app on another phone.
Page {
    id: page
    property var app
    // Shows the number step again while a code is awaited ("new code").
    property bool editingNumber: false
    property string errorMessage: ""

    // "number": register this phone with a phone number (SMS/call code);
    // "link": link it as an additional device of an existing account.
    property string mode: "number"
    readonly property bool linking: Signal.state === "linking"
    readonly property bool codeStep: Signal.state === "awaitingCode" && !editingNumber
    readonly property bool numberStep: mode === "number" && !codeStep && !linking
    readonly property int codeLength: 6

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: qsTr("Set up Signal")
        showBack: false
    }

    function requestCode(captcha) {
        page.errorMessage = ""
        page.app.settings.phone = phoneField.text.trim()
        Signal.registerNumber(page.app.settings.phone, captcha, voiceCheck.checked)
    }

    function openCaptcha() {
        page.app.stack.push(Qt.resolvedUrl("CaptchaPage.qml"),
                            { app: page.app, deliver: page.requestCode })
    }

    Connections {
        target: Signal
        onErrorOccurred: {
            if (action === "register" || action === "confirm" || action === "link")
                page.errorMessage = page.app.errorText(kind, message)
        }
        onStateChanged: {
            if (Signal.state === "awaitingCode") {
                page.editingNumber = false
                codeField.text = ""
            }
        }
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
            spacing: page.app.spacingUnit

            // How to set up: own number, or link to the account of another
            // device (like Signal Desktop).
            RowLayout {
                Layout.fillWidth: true
                visible: !page.codeStep && !page.linking
                spacing: page.app.gu

                Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    checkable: true
                    checked: page.mode === "number"
                    text: qsTr("Phone number")
                    onClicked: page.mode = "number"
                }
                Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    checkable: true
                    checked: page.mode === "link"
                    text: qsTr("Link device")
                    onClicked: page.mode = "link"
                }
            }

            AppLabel {
                Layout.fillWidth: true
                visible: page.mode === "link" && !page.codeStep
                wrapMode: Text.Wrap
                text: qsTr("Use the Signal account of your other phone on this one as well, "
                           + "like Signal Desktop. Both stay signed in.")
            }

            Button {
                Layout.fillWidth: true
                visible: page.mode === "link" && !page.linking && !page.codeStep
                text: qsTr("Show QR code")
                onClicked: {
                    page.errorMessage = ""
                    Signal.linkDevice()
                }
            }

            AppLabel {
                Layout.fillWidth: true
                visible: page.linking
                wrapMode: Text.Wrap
                text: qsTr("On your other phone, open Signal → Settings → Linked devices, "
                           + "tap + and scan this code.")
            }

            // Black on white, as scanners expect, in light and dark mode.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: page.linking
                implicitWidth: Math.min(content.width, page.app.gu * 32)
                implicitHeight: implicitWidth
                color: "#ffffff"

                Image {
                    anchors.fill: parent
                    source: Signal.linkQrPath.length ? "file://" + Signal.linkQrPath : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    cache: false
                }
                BusyIndicator {
                    anchors.centerIn: parent
                    running: page.linking && !Signal.linkQrPath.length
                    visible: running
                }
            }

            Button {
                Layout.fillWidth: true
                visible: page.linking
                flat: true
                text: qsTr("Cancel")
                onClicked: Signal.cancelLink()
            }

            AppLabel {
                Layout.fillWidth: true
                visible: page.numberStep
                wrapMode: Text.Wrap
                text: qsTr("UT Langis becomes the Signal app for your number on this phone. "
                           + "Signal on another phone with the same number will be signed out.")
            }

            AppLabel {
                Layout.fillWidth: true
                visible: page.numberStep
                wrapMode: Text.Wrap
                color: page.app.colorSecondaryText
                font.pixelSize: page.app.fontSecondary
                text: qsTr("If you set a Signal PIN with registration lock, turn the lock off "
                           + "in your old Signal app first.")
            }

            AppField {
                id: phoneField
                Layout.fillWidth: true
                visible: page.numberStep
                text: page.app.settings.phone
                placeholderText: qsTr("Phone number, e.g. +491701234567")
                inputMethodHints: Qt.ImhDialableCharactersOnly
            }

            CheckBox {
                id: voiceCheck
                Layout.fillWidth: true
                visible: page.numberStep
                text: qsTr("Call me instead of sending an SMS")
                // The style's own label ignores the app palette.
                contentItem: AppLabel {
                    leftPadding: voiceCheck.indicator.width + voiceCheck.spacing
                    text: voiceCheck.text
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                Layout.fillWidth: true
                visible: page.numberStep
                enabled: !Signal.busy && phoneField.text.trim().length > 4
                text: qsTr("Continue")
                onClicked: page.openCaptcha()
            }

            AppLabel {
                Layout.fillWidth: true
                visible: page.codeStep
                wrapMode: Text.Wrap
                text: qsTr("Enter the code Signal sent to %1.").arg(Signal.phone)
            }

            AppField {
                id: codeField
                Layout.fillWidth: true
                visible: page.codeStep
                placeholderText: qsTr("Verification code")
                inputMethodHints: Qt.ImhDigitsOnly
                maximumLength: page.codeLength + 1
            }

            Button {
                Layout.fillWidth: true
                visible: page.codeStep
                enabled: !Signal.busy
                         && codeField.text.replace(/\D/g, "").length === page.codeLength
                text: qsTr("Confirm")
                onClicked: {
                    page.errorMessage = ""
                    Signal.confirmCode(codeField.text)
                }
            }

            Button {
                Layout.fillWidth: true
                visible: page.codeStep || Signal.state === "awaitingCode"
                enabled: !Signal.busy
                flat: true
                text: page.codeStep ? qsTr("Request a new code") : qsTr("Enter the code")
                onClicked: page.editingNumber = page.codeStep
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: Signal.busy
                running: visible
            }

            AppLabel {
                Layout.fillWidth: true
                visible: page.errorMessage.length > 0
                wrapMode: Text.Wrap
                color: page.app.colorError
                text: page.errorMessage
            }
        }
    }
}
