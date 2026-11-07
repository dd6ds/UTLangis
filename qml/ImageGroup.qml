import QtQuick 2.12
import QtQuick.Controls 2.12

// The images of a message inside its bubble. One image is shown whole;
// several are packed into a 2-column grid of square tiles, at most
// maxTiles, the last tile saying how many more there are ("+3"). Tapping an
// image opens all of them full screen at that image (ImageViewerPage).
Item {
    id: group
    property var app
    // Local file paths of the message's images.
    property var paths: []
    // Widest the group may be (the bubble's room). Sizes are worked out from
    // this and not from `width`, which the bubble's layout sets from them.
    property real maxWidth: app.gu * 30

    // Press and hold (the bubble's own handler is underneath).
    signal pressAndHeld()
    // The message, for reacting and replying from the full-screen view.
    property var message: null

    readonly property int maxTiles: 4
    readonly property int columns: 2
    readonly property real gap: Math.max(2, app.gu * 0.3)
    readonly property bool single: paths.length === 1
    readonly property int tiles: Math.min(paths.length, maxTiles)
    readonly property real fullWidth: Math.min(app.gu * 30, maxWidth)
    readonly property real tileSize: (fullWidth - gap * (columns - 1)) / columns

    implicitWidth: single ? singleImage.width : fullWidth
    implicitHeight: single ? singleImage.height
                           : Math.ceil(tiles / columns) * (tileSize + gap) - gap

    Image {
        id: singleImage
        visible: group.single
        // Scaled down to the room there is, keeping its proportions.
        width: Math.min(implicitWidth, group.maxWidth)
        height: implicitWidth > 0 ? implicitHeight * width / implicitWidth : 0
        source: group.single ? "file://" + group.paths[0] : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        autoTransform: true
        sourceSize.width: group.app.gu * 30

        MouseArea {
            anchors.fill: parent
            onClicked: group.app.openImages(group.paths, 0, group.message)
            onPressAndHold: group.pressAndHeld()
        }
    }

    Grid {
        visible: !group.single
        columns: group.columns
        spacing: group.gap

        Repeater {
            model: group.single ? 0 : group.tiles
            delegate: Item {
                id: tile
                width: group.tileSize
                height: group.tileSize

                // The last tile stands for the images that do not fit.
                readonly property int hidden: index === group.tiles - 1
                                              ? group.paths.length - group.tiles : 0

                Image {
                    anchors.fill: parent
                    source: "file://" + group.paths[index]
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    autoTransform: true
                    sourceSize.width: group.tileSize
                    sourceSize.height: group.tileSize
                    clip: true
                }

                Rectangle {
                    anchors.fill: parent
                    visible: tile.hidden > 0
                    color: "#99000000"

                    Text {
                        anchors.centerIn: parent
                        text: "+" + tile.hidden
                        color: "#ffffff"
                        font.pixelSize: group.app.fontTitle * 1.3
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: group.app.openImages(group.paths, index, group.message)
                    onPressAndHold: group.pressAndHeld()
                }
            }
        }
    }
}
