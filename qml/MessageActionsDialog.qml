import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// What to do with a message, opened by pressing and holding it in the chat:
// react with an emoji (👍 👎 ...), reply to it, delete it on this phone, or delete it for everyone in the
// conversation. The latter is offered for own messages that Signal still
// lets us delete.
Dialog {
    id: dialog
    property var app
    // The message, as a {ts, outgoing, sender, text, senderName, myReaction}
    // object; myReaction is our own reaction to it ("" = none).
    property var message: ({})

    // Offered as quick reactions, like Signal's own apps.
    readonly property var quickReactions: ["👍", "👎", "❤️", "😂", "😮", "😢"]

    signal replyRequested(var message)

    // Signal only honours "delete for everyone" for recent messages.
    readonly property real everyoneWindowMs: 24 * 60 * 60 * 1000
    readonly property bool canDeleteForEveryone:
        message.outgoing === true && Date.now() - message.ts < everyoneWindowMs

    function openFor(target) {
        message = target
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true

    // Tapping one's own reaction again takes it back.
    function react(emoji) {
        Signal.react(message.ts, message.outgoing ? "" : message.sender, emoji,
                     message.myReaction === emoji)
        close()
    }

    ColumnLayout {
        // availableWidth, not parent.width: the dialog's size follows its
        // content, so filling the parent would bind both ways.
        width: dialog.availableWidth
        spacing: dialog.app.spacingUnit

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: dialog.quickReactions
                delegate: ToolButton {
                    Layout.fillWidth: true
                    text: modelData
                    font.family: "Noto Color Emoji"
                    font.pixelSize: dialog.app.fontTitle * 1.2
                    checked: dialog.message.myReaction === modelData
                    Accessible.name: qsTr("React with %1").arg(modelData)
                    onClicked: dialog.react(modelData)
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: qsTr("Reply")
            onClicked: {
                dialog.replyRequested(dialog.message)
                dialog.close()
            }
        }

        Button {
            Layout.fillWidth: true
            text: qsTr("Delete for me")
            onClicked: {
                Signal.deleteMessage(dialog.message.ts, false)
                dialog.close()
            }
        }

        Button {
            Layout.fillWidth: true
            visible: dialog.canDeleteForEveryone
            text: qsTr("Delete for everyone")
            onClicked: {
                Signal.deleteMessage(dialog.message.ts, true)
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
