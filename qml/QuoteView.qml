import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// The quoted message of a reply: an accent bar, the author and up to two
// lines of the quoted text. Used in message bubbles and above the input row
// while writing a reply.
Item {
    id: quote
    property var app
    property string author
    // "" when the quoted message only had attachments.
    property string quotedText
    property color textColor

    implicitWidth: content.implicitWidth + bar.width + app.gu
    implicitHeight: content.implicitHeight + app.gu * 0.6

    Rectangle {
        id: bar
        width: Math.max(2, quote.app.gu * 0.3)
        height: parent.height
        radius: width / 2
        color: quote.app.colorAccent
    }

    ColumnLayout {
        id: content
        x: bar.width + quote.app.gu
        y: quote.app.gu * 0.3
        width: quote.width - x
        spacing: 0

        Label {
            Layout.fillWidth: true
            visible: text.length > 0
            text: quote.author
            color: quote.textColor
            font.bold: true
            font.pixelSize: quote.app.fontSecondary
            elide: Text.ElideRight
        }
        Label {
            Layout.fillWidth: true
            text: quote.quotedText.length ? quote.quotedText : "📎"
            color: quote.textColor
            opacity: 0.8
            font.pixelSize: quote.app.fontSecondary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }
}
