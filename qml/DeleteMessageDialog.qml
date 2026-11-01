import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Asks how to delete a message (opened by pressing and holding it in the
// chat): only on this phone, or for everyone in the conversation. The latter
// is offered for own messages that Signal still lets us delete.
Dialog {
    id: dialog
    property var app
    property real ts: 0
    property bool outgoing: false

    // Signal only honours "delete for everyone" for recent messages.
    readonly property real everyoneWindowMs: 24 * 60 * 60 * 1000
    readonly property bool canDeleteForEveryone:
        outgoing && Date.now() - ts < everyoneWindowMs

    function openFor(messageTs, messageOutgoing) {
        ts = messageTs
        outgoing = messageOutgoing
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    title: qsTr("Delete message?")

    ColumnLayout {
        width: parent.width
        spacing: dialog.app.spacingUnit

        Button {
            Layout.fillWidth: true
            text: qsTr("Delete for me")
            onClicked: {
                Signal.deleteMessage(dialog.ts, false)
                dialog.close()
            }
        }

        Button {
            Layout.fillWidth: true
            visible: dialog.canDeleteForEveryone
            text: qsTr("Delete for everyone")
            onClicked: {
                Signal.deleteMessage(dialog.ts, true)
                dialog.close()
            }
        }

        Button {
            Layout.fillWidth: true
            flat: true
            text: qsTr("Cancel")
            onClicked: dialog.close()
        }
    }
}
