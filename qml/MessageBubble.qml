import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One message: own messages on the right, others on the left with the
// sender's name in groups. Images are shown inline, other attachments as
// their file name. Press and hold offers to delete it. Uses the roles of
// MessageListModel.
Item {
    id: bubble
    property var app

    // Press and hold on the bubble.
    signal deleteRequested()

    readonly property real maxBubbleWidth: width * 0.8
    readonly property color textColor: outgoing ? app.colorBubbleOwnText : app.colorText

    implicitHeight: box.height

    Rectangle {
        id: box
        anchors.right: outgoing ? parent.right : undefined
        anchors.left: outgoing ? undefined : parent.left
        anchors.rightMargin: bubble.app.gu
        anchors.leftMargin: bubble.app.gu
        width: Math.min(bubble.maxBubbleWidth, content.implicitWidth + 2 * bubble.app.gu)
        height: content.implicitHeight + 1.4 * bubble.app.gu
        radius: bubble.app.gu * 1.2
        color: outgoing ? bubble.app.colorBubbleOwn : bubble.app.colorBubbleOther

        MouseArea {
            anchors.fill: parent
            onPressAndHold: bubble.deleteRequested()
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

            Repeater {
                model: attachments
                delegate: AttachmentView {
                    Layout.maximumWidth: bubble.maxBubbleWidth - 2 * bubble.app.gu
                    app: bubble.app
                    path: modelData.path
                    contentType: modelData.type
                    textColor: bubble.textColor
                    onPressAndHeld: bubble.deleteRequested()
                }
            }

            Label {
                Layout.maximumWidth: bubble.maxBubbleWidth - 2 * bubble.app.gu
                visible: text.length > 0
                text: model.text
                color: bubble.textColor
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            Label {
                Layout.alignment: Qt.AlignRight
                text: bubble.app.timeText(ts)
                color: bubble.textColor
                opacity: 0.7
                font.pixelSize: bubble.app.fontSecondary * 0.85
            }
        }
    }
}
