import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One conversation in the list: name, latest message, time and unread count.
// Uses the roles of ThreadListModel (title, lastText, lastTs, unread).
ItemDelegate {
    id: row
    property var app

    padding: app.spacingUnit
    background: Rectangle {
        color: row.pressed ? row.app.colorSurfacePressed : "transparent"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: row.app.colorBorder
        }
    }

    contentItem: RowLayout {
        spacing: row.app.spacingUnit

        ColumnLayout {
            Layout.fillWidth: true
            spacing: row.app.gu * 0.3

            AppLabel {
                Layout.fillWidth: true
                text: (title.length ? title : qsTr("Unknown contact"))
                      + (Notifications.mutedThreads.indexOf(thread) >= 0 ? "  🔕" : "")
                font.bold: unread > 0
                elide: Text.ElideRight
            }
            AppLabel {
                Layout.fillWidth: true
                text: lastText
                color: row.app.colorSecondaryText
                font.pixelSize: row.app.fontSecondary
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        ColumnLayout {
            spacing: row.app.gu * 0.3

            AppLabel {
                Layout.alignment: Qt.AlignRight
                text: row.app.timeText(lastTs)
                color: row.app.colorSecondaryText
                font.pixelSize: row.app.fontSecondary
            }
            Rectangle {
                Layout.alignment: Qt.AlignRight
                visible: unread > 0
                implicitWidth: Math.max(implicitHeight, unreadText.implicitWidth + row.app.gu)
                implicitHeight: unreadText.implicitHeight + row.app.gu * 0.4
                radius: implicitHeight / 2
                color: row.app.colorAccent

                Text {
                    id: unreadText
                    anchors.centerIn: parent
                    text: unread
                    color: "#ffffff"
                    font.pixelSize: row.app.fontSecondary
                    font.bold: true
                }
            }
        }
    }
}
