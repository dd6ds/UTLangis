import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Under a full-screen image or video: react to its message with an emoji,
// or reply to it (back in the chat, with the message quoted).
Rectangle {
    id: bar
    property var app
    // The message the image or video belongs to, as MessageActionsDialog
    // gets it: {ts, outgoing, sender, text, senderName, myReaction}.
    property var message: null

    readonly property var quickReactions: ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    function react(emoji) {
        var remove = message.myReaction === emoji
        Signal.react(message.ts, message.outgoing ? "" : message.sender, emoji, remove)
        // Shown at once; the chat gets the reaction from the backend.
        var changed = Object.assign({}, message)
        changed.myReaction = remove ? "" : emoji
        message = changed
    }

    implicitHeight: row.implicitHeight + 2 * app.gu
    color: "#99000000"

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: bar.app.gu
        spacing: 0

        Repeater {
            model: bar.quickReactions
            delegate: ToolButton {
                Layout.fillWidth: true
                text: modelData
                font.family: "Noto Color Emoji"
                font.pixelSize: bar.app.fontTitle * 1.1
                Accessible.name: qsTr("React with %1").arg(modelData)
                background: Rectangle {
                    radius: height / 2
                    color: bar.message && bar.message.myReaction === modelData
                           ? "#66ffffff" : "transparent"
                }
                onClicked: bar.react(modelData)
            }
        }

        ToolButton {
            text: "↩ " + qsTr("Reply")
            font.pixelSize: bar.app.fontSecondary * 1.1
            palette.buttonText: "#ffffff"
            onClicked: bar.app.replyInChat(bar.message)
        }
    }
}
