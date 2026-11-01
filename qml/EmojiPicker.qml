import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import Qt.labs.settings 1.0
import "emojis.js" as Emojis

// Emoji panel below the chat's input row: a row of categories (the first
// one holds the recently used emoji) and a grid; tapping an emoji emits
// `picked`. The recently used ones are remembered across starts.
Rectangle {
    id: picker
    property var app

    signal picked(string emoji)

    readonly property int recentMax: 28
    readonly property real cellSize: app.gu * 4.4
    // -1 = recently used, otherwise an index into Emojis.categories.
    property int category: recentList.length ? -1 : 0
    property var recentList: settings.recent.length ? settings.recent.split("\n") : []

    color: app.colorSurface

    Settings {
        id: settings
        category: "emoji"
        property string recent: ""
    }

    function choose(emoji) {
        var list = recentList.filter(function (e) { return e !== emoji })
        list.unshift(emoji)
        settings.recent = list.slice(0, recentMax).join("\n")
        picker.picked(emoji)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: tabs
            Layout.fillWidth: true
            Layout.preferredHeight: picker.cellSize
            orientation: ListView.Horizontal
            clip: true
            // "recent" first, then the categories by index.
            model: [-1].concat(Emojis.categories.map(function (c, i) { return i }))
            delegate: ToolButton {
                width: picker.cellSize
                height: picker.cellSize
                text: modelData < 0 ? "🕘" : Emojis.categories[modelData][0]
                font.pixelSize: picker.app.fontTitle
                checked: picker.category === modelData
                onClicked: {
                    picker.category = modelData
                    grid.positionViewAtBeginning()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: picker.app.colorBorder
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            // Columns spread over the full width.
            cellWidth: width / Math.max(1, Math.floor(width / picker.cellSize))
            cellHeight: picker.cellSize
            model: picker.category < 0 ? picker.recentList
                                       : Emojis.categories[picker.category]
            delegate: ItemDelegate {
                width: grid.cellWidth
                height: grid.cellHeight
                padding: 0
                contentItem: Text {
                    text: modelData
                    font.family: "Noto Color Emoji"
                    font.pixelSize: picker.app.fontTitle * 1.1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: picker.choose(modelData)
            }
        }
    }
}
