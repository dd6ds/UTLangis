import QtQuick 2.12
import QtQuick.Controls 2.12

// A call in the chat: a small centred line such as "📞 Missed call 14:02".
Item {
    id: row
    property var app
    // How the call ended (MessageListModel's call role).
    property string outcome: ""
    property bool isVideo: false
    property real time: 0

    readonly property bool missed: outcome === "missed"

    function describe() {
        switch (outcome) {
        case "missed":
            return isVideo ? qsTr("Missed video call") : qsTr("Missed call")
        case "declined":
            return isVideo ? qsTr("Declined video call") : qsTr("Declined call")
        case "answeredElsewhere":
            return qsTr("Call answered on another device")
        case "declinedElsewhere":
            return qsTr("Call declined on another device")
        default:
            return isVideo ? qsTr("Video call") : qsTr("Call")
        }
    }

    implicitHeight: pill.height + app.gu

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: Math.min(row.width - 2 * row.app.spacingUnit,
                        label.implicitWidth + 2 * row.app.spacingUnit)
        height: label.implicitHeight + row.app.gu
        radius: height / 2
        color: row.app.colorSurface

        AppLabel {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pill.width - row.app.spacingUnit)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: row.app.fontSecondary
            color: row.missed ? row.app.colorError : row.app.colorSecondaryText
            text: (row.isVideo ? "🎥 " : "📞 ") + row.describe() + "  "
                  + row.app.timeText(row.time)
        }
    }
}
