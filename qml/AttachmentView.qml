import QtQuick 2.12
import QtQuick.Controls 2.12

// An attachment inside a message bubble: images inline, anything else as its
// file name.
Item {
    id: view
    property var app
    property string path
    property string contentType
    property color textColor

    readonly property bool isImage: contentType.indexOf("image/") === 0

    implicitWidth: isImage ? image.implicitWidth : fileLabel.implicitWidth
    implicitHeight: isImage ? image.implicitHeight : fileLabel.implicitHeight

    Image {
        id: image
        visible: view.isImage
        width: Math.min(implicitWidth, view.width)
        source: view.isImage ? "file://" + view.path : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: view.app.gu * 30
    }

    Label {
        id: fileLabel
        visible: !view.isImage
        width: view.width
        text: "📄 " + view.path.split("/").pop()
        color: view.textColor
        elide: Text.ElideMiddle
    }
}
