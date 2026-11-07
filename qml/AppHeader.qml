import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Title bar of a page, flat like Signal's: optional back button, the chat's
// avatar (avatarKey set), title, and buttons the page adds as children on
// the right.
Rectangle {
    id: header
    property var app
    property string title
    property bool showBack: true
    // Chat key for the avatar next to the title; "" = no avatar.
    property string avatarKey: ""
    property bool groupAvatar: false
    default property alias actions: actionRow.data

    signal back()

    implicitHeight: app.gu * 7
    color: app.colorBackground

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: app.gu
        anchors.rightMargin: app.gu
        spacing: app.gu

        ToolButton {
            visible: header.showBack
            text: "‹"
            font.pixelSize: app.fontTitle * 1.6
            Accessible.name: qsTr("Back")
            onClicked: header.back()
        }

        Avatar {
            visible: header.avatarKey.length > 0
            app: header.app
            size: header.app.gu * 4.5
            name: header.title
            colorKey: header.avatarKey
            group: header.groupAvatar
        }

        AppLabel {
            Layout.fillWidth: true
            Layout.leftMargin: header.showBack ? 0 : app.gu
            text: header.title
            font.pixelSize: header.avatarKey.length ? app.fontTitle * 0.9 : app.fontTitle * 1.1
            font.weight: Font.DemiBold
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
        opacity: 0.5
    }
}
