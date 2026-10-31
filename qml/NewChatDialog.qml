import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Asks for a phone number, or offers to pick one from the address book, and
// looks up its Signal account. ChatsPage opens the chat when Signal reports
// chatStarted.
Dialog {
    id: dialog
    property var app

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    title: qsTr("New chat")
    standardButtons: Dialog.Cancel

    onOpened: {
        phoneField.text = ""
        phoneField.forceActiveFocus()
    }

    ColumnLayout {
        width: parent.width
        spacing: dialog.app.spacingUnit

        Button {
            Layout.fillWidth: true
            text: qsTr("Choose from contacts")
            onClicked: {
                dialog.close()
                dialog.app.chooseContact()
            }
        }

        AppField {
            id: phoneField
            Layout.fillWidth: true
            placeholderText: qsTr("or enter a phone number")
            inputMethodHints: Qt.ImhDialableCharactersOnly
            onAccepted: startButton.clicked()
        }

        Button {
            id: startButton
            Layout.fillWidth: true
            enabled: !Signal.busy && phoneField.text.trim().length > 4
            text: Signal.busy ? qsTr("Looking up...") : qsTr("Start chat")
            onClicked: Signal.startChat(phoneField.text.trim(), "")
        }
    }
}
