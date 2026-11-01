import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Sets the profile name people see in their Signal app. A new account has
// none, so ChatsPage opens this once after registering; Settings offers it
// again.
Dialog {
    id: dialog
    property var app

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    title: qsTr("Your name")
    standardButtons: Dialog.Ok | Dialog.Cancel

    onOpened: nameField.forceActiveFocus()
    onAccepted: {
        if (nameField.text.trim().length)
            Signal.setProfileName(nameField.text.trim())
    }

    ColumnLayout {
        // availableWidth, not parent.width: the dialog's size follows its
        // content, so filling the parent would bind both ways.
        width: dialog.availableWidth
        spacing: dialog.app.spacingUnit

        AppLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("This name is shown to the people you write to.")
        }

        AppField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: qsTr("Name")
        }
    }
}
