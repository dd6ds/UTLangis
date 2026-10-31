import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Title bar of a page: optional back button, title, and buttons the page
// adds as children on the right.
Rectangle {
    id: header
    property var app
    property string title
    property bool showBack: true
    default property alias actions: actionRow.data

    signal back()

    implicitHeight: app.gu * 6
    color: app.colorSurface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: app.gu
        anchors.rightMargin: app.gu
        spacing: app.gu

        ToolButton {
            visible: header.showBack
            text: "‹"
            font.pixelSize: app.fontTitle * 1.4
            Accessible.name: qsTr("Back")
            onClicked: header.back()
        }

        AppLabel {
            Layout.fillWidth: true
            Layout.leftMargin: header.showBack ? 0 : app.gu
            text: header.title
            font.pixelSize: app.fontTitle
            font.bold: true
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        Row {
            id: actionRow
            spacing: app.gu
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: app.colorBorder
    }
}
