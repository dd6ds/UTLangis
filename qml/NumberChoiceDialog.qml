import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// For a picked contact with several phone numbers: which one to write to.
Dialog {
    id: dialog
    property var app
    // { name, numbers: [..] } from Signal.readContactCard.
    property var contact: ({ name: "", numbers: [] })

    function openFor(picked) {
        contact = picked
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    title: contact.name.length ? contact.name : qsTr("Choose a number")
    standardButtons: Dialog.Cancel

    ColumnLayout {
        // availableWidth, not parent.width: the dialog's size follows its
        // content, so filling the parent would bind both ways.
        width: dialog.availableWidth
        spacing: dialog.app.gu

        Repeater {
            model: dialog.contact.numbers
            delegate: Button {
                Layout.fillWidth: true
                text: modelData
                onClicked: {
                    dialog.close()
                    Signal.startChat(modelData, dialog.contact.name)
                }
            }
        }
    }
}
