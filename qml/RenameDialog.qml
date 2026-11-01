import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Gives the open one-to-one chat the user's own name, e.g. for someone who
// is not in the address book. An empty name goes back to the name from the
// person's Signal profile.
Dialog {
    id: dialog
    property var app

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    title: qsTr("Rename")
    standardButtons: Dialog.Ok | Dialog.Cancel

    onOpened: {
        nameField.text = Signal.currentTitle
        nameField.forceActiveFocus()
        nameField.selectAll()
    }
    onAccepted: {
        Qt.inputMethod.commit()
        Signal.renameThread(nameField.text.trim())
    }

    ColumnLayout {
        // availableWidth, not parent.width: the dialog's size follows its
        // content, so filling the parent would bind both ways.
        width: dialog.availableWidth
        spacing: dialog.app.spacingUnit

        AppField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: qsTr("Name")
            onAccepted: dialog.accept()
        }

        AppLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: dialog.app.colorSecondaryText
            font.pixelSize: dialog.app.fontSecondary
            text: qsTr("Leave empty to use the name from the person's Signal profile.")
        }
    }
}
