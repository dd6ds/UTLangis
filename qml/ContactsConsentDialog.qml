import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Asks once before ubSignal reads the address book. The answer is kept in
// app.settings.contactsAccess ("allowed" / "denied") and can be changed in
// Settings. The address book is not touched before the user allows it.
Dialog {
    id: dialog
    property var app

    signal allowed()

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    closePolicy: Popup.NoAutoClose
    title: qsTr("Access contacts?")

    footer: DialogButtonBox {
        Button {
            text: qsTr("Don't allow")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: qsTr("Allow")
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }

    onAccepted: {
        app.settings.contactsAccess = "allowed"
        dialog.allowed()
    }
    onRejected: app.settings.contactsAccess = "denied"

    ColumnLayout {
        // availableWidth, not parent.width: the dialog's size follows its
        // content, so filling the parent would bind both ways.
        width: dialog.availableWidth
        spacing: dialog.app.spacingUnit

        AppLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("ubSignal would like to read your address book so you can pick "
                       + "the person to write to.")
        }

        AppLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: dialog.app.colorSecondaryText
            font.pixelSize: dialog.app.fontSecondary
            text: qsTr("Your contacts stay on this phone. Only the number you choose is "
                       + "looked up at Signal. You can change this later in Settings.")
        }
    }
}
