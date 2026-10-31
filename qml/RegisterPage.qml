import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Registers this phone as the Signal device of a phone number: number and
// captcha first (CaptchaPage), then the code Signal sends by SMS or call.
Page {
    id: page
    property var app
    // Shows the number step again while a code is awaited ("new code").
    property bool editingNumber: false
    property string errorMessage: ""

    readonly property bool codeStep: Signal.state === "awaitingCode" && !editingNumber
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
            if (action === "register" || action === "confirm")
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
            width: parent.width - 2 * page.app.spacingUnit
            spacing: page.app.spacingUnit

            AppLabel {
                Layout.fillWidth: true
                visible: !page.codeStep
                wrapMode: Text.Wrap
                text: qsTr("ubSignal becomes the Signal app for your number on this phone. "
                           + "Signal on another phone with the same number will be signed out.")
            }

            AppLabel {
                Layout.fillWidth: true
                visible: !page.codeStep
                wrapMode: Text.Wrap
                color: page.app.colorSecondaryText
                font.pixelSize: page.app.fontSecondary
                text: qsTr("If you set a Signal PIN with registration lock, turn the lock off "
                           + "in your old Signal app first.")
            }

            AppField {
                id: phoneField
                Layout.fillWidth: true
                visible: !page.codeStep
                text: page.app.settings.phone
                placeholderText: qsTr("Phone number, e.g. +491701234567")
                inputMethodHints: Qt.ImhDialableCharactersOnly
            }

            CheckBox {
                id: voiceCheck
                Layout.fillWidth: true
                visible: !page.codeStep
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
                visible: !page.codeStep
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
