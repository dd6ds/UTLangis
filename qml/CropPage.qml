import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Crops (and turns) a photo: a frame over the image whose corners and edges
// can be dragged, and which moves when dragged inside. "Done" hands the
// result, a new file, to `accept` (the original is never changed).
Page {
    id: page
    property var app
    // file:// URL or path of the photo.
    property string source: ""
    // Called with the file:// URL of the result.
    property var accept: null

    // The crop frame in fractions (0..1) of the upright image.
    property real cropX: 0
    property real cropY: 0
    property real cropW: 1
    property real cropH: 1
    // Turned since the page was opened, so the result needs a new file even
    // without cropping.
    property bool turned: false

    readonly property bool cropped: cropX > 0.001 || cropY > 0.001
                                    || cropW < 0.999 || cropH < 0.999

    function resetFrame() {
        cropX = 0
        cropY = 0
        cropW = 1
        cropH = 1
    }

    function turn(clockwise) {
        var url = ImageEditor.rotate(page.source, clockwise)
        if (!url.length) {
            page.app.showNote(qsTr("The photo could not be edited."))
            return
        }
        page.source = url
        page.turned = true
        resetFrame()
    }

    function finish() {
        var url = page.source
        if (page.cropped)
            url = ImageEditor.crop(page.source, cropX, cropY, cropW, cropH)
        else if (url.indexOf("/") === 0)
            url = "file://" + url
        if (!url.length) {
            page.app.showNote(qsTr("The photo could not be edited."))
            return
        }
        var accept = page.accept
        page.app.stack.pop()
        if (accept)
            accept(url)
    }

    background: Rectangle { color: "#000000" }

    header: AppHeader {
        app: page.app
        title: qsTr("Crop")
        onBack: page.app.stack.pop()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true

            Image {
                id: photo
                anchors.fill: parent
                anchors.margins: page.app.spacingUnit
                source: page.source.indexOf("/") === 0 ? "file://" + page.source : page.source
                fillMode: Image.PreserveAspectFit
                autoTransform: true
                asynchronous: true
                // Enough for the screen; the crop itself uses the full photo.
                sourceSize.width: 2048
                sourceSize.height: 2048
            }

            // The part of `photo` the image is drawn in.
            Item {
                id: picture
                x: photo.x + (photo.width - photo.paintedWidth) / 2
                y: photo.y + (photo.height - photo.paintedHeight) / 2
                width: photo.paintedWidth
                height: photo.paintedHeight
                visible: photo.status === Image.Ready

                readonly property real frameLeft: page.cropX * width
                readonly property real frameTop: page.cropY * height
                readonly property real frameRight: (page.cropX + page.cropW) * width
                readonly property real frameBottom: (page.cropY + page.cropH) * height

                // Darkened outside the frame.
                Rectangle {
                    color: "#99000000"
                    x: 0; y: 0; width: parent.width; height: picture.frameTop
                }
                Rectangle {
                    color: "#99000000"
                    x: 0; y: picture.frameBottom
                    width: parent.width; height: parent.height - picture.frameBottom
                }
                Rectangle {
                    color: "#99000000"
                    x: 0; y: picture.frameTop
                    width: picture.frameLeft; height: picture.frameBottom - picture.frameTop
                }
                Rectangle {
                    color: "#99000000"
                    x: picture.frameRight; y: picture.frameTop
                    width: parent.width - picture.frameRight
                    height: picture.frameBottom - picture.frameTop
                }

                Rectangle {
                    id: frame
                    x: picture.frameLeft
                    y: picture.frameTop
                    width: picture.frameRight - picture.frameLeft
                    height: picture.frameBottom - picture.frameTop
                    color: "transparent"
                    border.color: "#ffffff"
                    border.width: Math.max(1, page.app.gu * 0.25)

                    // Thirds, as a guide.
                    Repeater {
                        model: 2
                        Rectangle {
                            x: frame.width * (index + 1) / 3
                            width: 1; height: frame.height
                            color: "#80ffffff"
                        }
                    }
                    Repeater {
                        model: 2
                        Rectangle {
                            y: frame.height * (index + 1) / 3
                            width: frame.width; height: 1
                            color: "#80ffffff"
                        }
                    }

                    // Corner marks.
                    Repeater {
                        model: 4
                        Rectangle {
                            readonly property real size: page.app.gu * 2.4
                            width: size; height: size
                            x: (index % 2 === 0) ? -size / 2 : frame.width - size / 2
                            y: (index < 2) ? -size / 2 : frame.height - size / 2
                            radius: size / 2
                            color: "#ffffff"
                            border.color: "#40000000"
                        }
                    }
                }
            }

            // One area for all dragging, a bit larger than the picture so the
            // corners can be grabbed at its edge: near an edge or corner of
            // the frame drags that, inside the frame moves it.
            MouseArea {
                id: dragger
                readonly property real grab: page.app.gu * 3.5
                property bool edgeLeft: false
                property bool edgeRight: false
                property bool edgeTop: false
                property bool edgeBottom: false
                property bool moving: false
                property point start
                property var startFrame

                x: picture.x - grab
                y: picture.y - grab
                width: picture.width + 2 * grab
                height: picture.height + 2 * grab
                enabled: picture.visible
                preventStealing: true

                function clamp(value, low, high) {
                    return Math.max(low, Math.min(high, value))
                }

                onPressed: {
                    var p = mapToItem(picture, mouse.x, mouse.y)
                    var x0 = picture.frameLeft, x1 = picture.frameRight
                    var y0 = picture.frameTop, y1 = picture.frameBottom
                    var g = grab
                    edgeLeft = Math.abs(p.x - x0) < g && p.y > y0 - g && p.y < y1 + g
                    edgeRight = Math.abs(p.x - x1) < g && p.y > y0 - g && p.y < y1 + g
                    edgeTop = Math.abs(p.y - y0) < g && p.x > x0 - g && p.x < x1 + g
                    edgeBottom = Math.abs(p.y - y1) < g && p.x > x0 - g && p.x < x1 + g
                    // A small frame: the nearer edge wins.
                    if (edgeLeft && edgeRight) {
                        edgeLeft = p.x < (x0 + x1) / 2
                        edgeRight = !edgeLeft
                    }
                    if (edgeTop && edgeBottom) {
                        edgeTop = p.y < (y0 + y1) / 2
                        edgeBottom = !edgeTop
                    }
                    moving = !(edgeLeft || edgeRight || edgeTop || edgeBottom)
                            && p.x > x0 && p.x < x1 && p.y > y0 && p.y < y1
                    start = p
                    startFrame = { x: page.cropX, y: page.cropY, w: page.cropW, h: page.cropH }
                    mouse.accepted = edgeLeft || edgeRight || edgeTop || edgeBottom || moving
                }

                onPositionChanged: {
                    if (picture.width <= 0 || picture.height <= 0)
                        return
                    var p = mapToItem(picture, mouse.x, mouse.y)
                    var dx = (p.x - start.x) / picture.width
                    var dy = (p.y - start.y) / picture.height
                    var s = startFrame
                    if (moving) {
                        page.cropX = clamp(s.x + dx, 0, 1 - s.w)
                        page.cropY = clamp(s.y + dy, 0, 1 - s.h)
                        return
                    }
                    var minW = page.app.gu * 6 / picture.width
                    var minH = page.app.gu * 6 / picture.height
                    var x0 = s.x, x1 = s.x + s.w, y0 = s.y, y1 = s.y + s.h
                    if (edgeLeft)
                        x0 = clamp(x0 + dx, 0, x1 - minW)
                    if (edgeRight)
                        x1 = clamp(x1 + dx, x0 + minW, 1)
                    if (edgeTop)
                        y0 = clamp(y0 + dy, 0, y1 - minH)
                    if (edgeBottom)
                        y1 = clamp(y1 + dy, y0 + minH, 1)
                    page.cropX = x0
                    page.cropY = y0
                    page.cropW = x1 - x0
                    page.cropH = y1 - y0
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                running: photo.status === Image.Loading
                visible: running
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: page.app.gu
            spacing: page.app.gu

            ToolButton {
                text: "⟲"
                font.pixelSize: page.app.fontTitle * 1.3
                palette.buttonText: "#ffffff"
                Accessible.name: qsTr("Turn left")
                onClicked: page.turn(false)
            }
            ToolButton {
                text: "⟳"
                font.pixelSize: page.app.fontTitle * 1.3
                palette.buttonText: "#ffffff"
                Accessible.name: qsTr("Turn right")
                onClicked: page.turn(true)
            }
            Button {
                text: qsTr("Reset")
                enabled: page.cropped
                onClicked: page.resetFrame()
            }
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Done")
                highlighted: true
                enabled: picture.visible
                onClicked: page.finish()
            }
        }
    }
}
