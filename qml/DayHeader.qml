import QtQuick 2.12

// The day ("Today", "Yesterday", a weekday or a date) above the first
// message of each day in a chat.
Item {
    id: header
    property var app
    // Sent time of the message below, ms since the epoch.
    property real time: 0

    height: chip.height + app.gu

    Rectangle {
        id: chip
        anchors.centerIn: parent
        width: dayText.implicitWidth + header.app.spacingUnit * 2
        height: dayText.implicitHeight + header.app.gu
        radius: height / 2
        color: header.app.colorSurface

        AppLabel {
            id: dayText
            anchors.centerIn: parent
            text: header.app.dayText(header.time)
            color: header.app.colorSecondaryText
            font.pixelSize: header.app.fontSecondary
            font.weight: Font.DemiBold
        }
    }
}
