import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "linkify.js" as Linkify

// One message: own messages on the right, others on the left with the
// sender's name in groups. Images are shown inline, several of them as a
// group (ImageGroup), other attachments as a player or their file name; a
// reply shows the quoted message on top. Press and hold offers to react,
// reply, edit or delete; reactions show below the bubble. Uses the roles of
// MessageListModel.
Item {
    id: bubble
    property var app

    // The message as the actions dialog and the image and video viewers
    // take it ({ts, outgoing, sender, text, senderName, myReaction}).
    property var info: null

    // Press and hold on the bubble: reply or delete.
    signal actionsRequested()

    readonly property real maxBubbleWidth: width * 0.8
    readonly property color textColor: outgoing ? app.colorBubbleOwnText : app.colorText

    function isImage(attachment) {
        return attachment.type.indexOf("image/") === 0
    }
    readonly property var imagePaths:
        attachments.filter(isImage).map(function (a) { return a.path })
    readonly property var otherAttachments:
        attachments.filter(function (a) { return !isImage(a) })

    // "👍 2  ❤️" for the reactions to this message ("" = none).
    readonly property string reactionSummary: {
        var counts = {}
        var order = []
        for (var reactor in reactions) {
            var emoji = reactions[reactor]
            if (counts[emoji] === undefined) {
                counts[emoji] = 0
                order.push(emoji)
            }
            counts[emoji] += 1
        }
        return order.map(function (e) { return counts[e] > 1 ? e + " " + counts[e] : e })
                    .join("  ")
    }

    implicitHeight: box.height + (reactionSummary.length ? reactionChip.height * 0.7 : 0)

    // Reactions, overlapping the lower edge of the bubble like in Signal.
    Rectangle {
        id: reactionChip
        z: 1
        visible: bubble.reactionSummary.length > 0
        anchors.top: box.bottom
        anchors.topMargin: -height * 0.3
        anchors.right: outgoing ? box.right : undefined
        anchors.left: outgoing ? undefined : box.left
        anchors.leftMargin: bubble.app.gu
        anchors.rightMargin: bubble.app.gu
        width: chipText.implicitWidth + bubble.app.gu * 1.2
        height: chipText.implicitHeight + bubble.app.gu * 0.4
        radius: height / 2
        color: bubble.app.colorSurface
        border.color: bubble.app.colorBorder

        Text {
            id: chipText
            anchors.centerIn: parent
            text: bubble.reactionSummary
            color: bubble.app.colorText
            font.family: "Noto Color Emoji"
            font.pixelSize: bubble.app.fontSecondary
        }
    }

    Rectangle {
        id: box
        anchors.right: outgoing ? parent.right : undefined
        anchors.left: outgoing ? undefined : parent.left
        anchors.rightMargin: bubble.app.gu
        anchors.leftMargin: bubble.app.gu
        width: Math.min(bubble.maxBubbleWidth, content.implicitWidth + 2 * bubble.app.gu)
        height: content.implicitHeight + 1.4 * bubble.app.gu
        radius: bubble.app.gu * 2
        color: outgoing ? bubble.app.colorBubbleOwn : bubble.app.colorBubbleOther

        MouseArea {
            anchors.fill: parent
            onPressAndHold: bubble.actionsRequested()
        }

        ColumnLayout {
            id: content
            x: bubble.app.gu
            y: bubble.app.gu * 0.7
            width: box.width - 2 * bubble.app.gu
            spacing: bubble.app.gu * 0.4

            AppLabel {
                visible: senderName.length > 0
                text: senderName
                color: bubble.app.colorAccent
                font.pixelSize: bubble.app.fontSecondary
                font.bold: true
            }

            QuoteView {
                Layout.maximumWidth: bubble.maxBubbleWidth - 2 * bubble.app.gu
                Layout.fillWidth: true
                visible: hasQuote
                app: bubble.app
                author: quoteOwn ? qsTr("You") : quoteAuthor
                quotedText: quoteText
                textColor: bubble.textColor
            }

            ImageGroup {
                Layout.preferredWidth: implicitWidth
                maxWidth: bubble.maxBubbleWidth - 2 * bubble.app.gu
                visible: bubble.imagePaths.length > 0
                app: bubble.app
                paths: bubble.imagePaths
                message: bubble.info
                onPressAndHeld: bubble.actionsRequested()
            }

            Repeater {
                model: bubble.otherAttachments
                delegate: AttachmentView {
                    Layout.maximumWidth: bubble.maxBubbleWidth - 2 * bubble.app.gu
                    app: bubble.app
                    path: modelData.path
                    contentType: modelData.type
                    textColor: bubble.textColor
                    message: bubble.info
                    onPressAndHeld: bubble.actionsRequested()
                }
            }

            // Web addresses in the text are links that open in the browser.
            Label {
                readonly property bool linked: Linkify.hasLink(model.text)
                Layout.maximumWidth: bubble.maxBubbleWidth - 2 * bubble.app.gu
                visible: model.text.length > 0
                text: linked ? Linkify.toStyledText(model.text) : model.text
                color: bubble.textColor
                linkColor: outgoing ? bubble.textColor : bubble.app.colorAccent
                wrapMode: Text.Wrap
                textFormat: linked ? Text.StyledText : Text.PlainText
                onLinkActivated: Qt.openUrlExternally(link)
            }

            // Time, and for own messages the delivery state: ✓ sent,
            // ✓✓ on the recipient's phone, green ✓✓ read.
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: bubble.app.gu * 0.5

                Label {
                    visible: edited
                    text: qsTr("edited")
                    color: bubble.textColor
                    opacity: 0.7
                    font.pixelSize: bubble.app.fontSecondary * 0.85
                    font.italic: true
                }
                Label {
                    text: bubble.app.timeText(ts)
                    color: bubble.textColor
                    opacity: 0.7
                    font.pixelSize: bubble.app.fontSecondary * 0.85
                }
                Label {
                    visible: outgoing && status > 0
                    text: status >= 2 ? "✓✓" : "✓"
                    color: status >= 3 ? bubble.app.colorReadReceipt : bubble.textColor
                    opacity: status >= 3 ? 1 : 0.7
                    font.pixelSize: bubble.app.fontSecondary * 0.85
                    font.bold: status >= 3
                    Accessible.name: status >= 3 ? qsTr("Read")
                                   : status >= 2 ? qsTr("Delivered") : qsTr("Sent")
                }
            }
        }
    }
}
