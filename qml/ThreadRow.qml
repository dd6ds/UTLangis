import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One conversation in the list, laid out like Signal's: avatar, name and
// latest message, time and unread count on the right.
// Uses the roles of ThreadListModel (thread, title, lastText, lastTs, unread).
ItemDelegate {
    id: row
    property var app

    readonly property string shownTitle: title.length ? title : qsTr("Unknown contact")
    readonly property bool muted: Notifications.mutedThreads.indexOf(thread) >= 0

    leftPadding: app.spacingUnit
    rightPadding: app.spacingUnit
    topPadding: app.gu
    bottomPadding: app.gu
    background: Rectangle {
        color: row.pressed ? row.app.colorSurfacePressed : "transparent"
    }

    contentItem: RowLayout {
        spacing: row.app.spacingUnit

        Avatar {
            app: row.app
            name: row.shownTitle
            colorKey: thread
            group: thread.indexOf("c:") !== 0
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: row.app.gu * 0.3

            RowLayout {
                Layout.fillWidth: true
                spacing: row.app.gu

                AppLabel {
                    Layout.fillWidth: true
                    text: row.shownTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
                AppLabel {
                    visible: row.muted
                    text: "🔕"
                    font.pixelSize: row.app.fontSecondary
                }
                AppLabel {
                    text: row.app.timeText(lastTs)
                    color: unread > 0 ? row.app.colorAccent : row.app.colorSecondaryText
                    font.pixelSize: row.app.fontSecondary
                    font.weight: unread > 0 ? Font.DemiBold : Font.Normal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: row.app.gu

                AppLabel {
                    Layout.fillWidth: true
                    text: lastText
                    color: unread > 0 ? row.app.colorText : row.app.colorSecondaryText
                    font.pixelSize: row.app.fontSecondary * 1.08
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                }
                Rectangle {
                    visible: unread > 0
                    implicitWidth: Math.max(implicitHeight,
                                            unreadText.implicitWidth + row.app.gu * 1.2)
                    implicitHeight: unreadText.implicitHeight + row.app.gu * 0.5
                    radius: implicitHeight / 2
                    color: row.muted ? row.app.colorInactive : row.app.colorAccent

                    Text {
                        id: unreadText
                        anchors.centerIn: parent
                        text: unread
                        color: "#ffffff"
                        font.pixelSize: row.app.fontSecondary * 0.9
                        font.bold: true
                    }
                }
            }
        }
    }
}
