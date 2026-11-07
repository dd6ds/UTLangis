import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Content 1.3

// Hands a received file to another app through the Content Hub: open it
// there (a video player, a document viewer) or save it (file manager,
// gallery). The other app gets its own copy.
Popup {
    id: picker
    // Local path and MIME type of the file to hand over.
    property string path: ""
    property string contentType: ""
    property var activeTransfer: null

    function exportFile(filePath, type) {
        picker.path = filePath
        picker.contentType = type
        picker.open()
    }

    readonly property var hubType: {
        if (contentType.indexOf("image/") === 0)
            return ContentType.Pictures
        if (contentType.indexOf("video/") === 0)
            return ContentType.Videos
        if (contentType.indexOf("audio/") === 0)
            return ContentType.Music
        if (contentType.indexOf("text/") === 0 || contentType.indexOf("application/pdf") === 0)
            return ContentType.Documents
        return ContentType.All
    }

    parent: Overlay.overlay
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: true

    // Created on first use, like ImportPicker: the Lomiri toolkit would slow
    // down the app start.
    property bool used: false
    onOpened: used = true

    Component {
        id: itemComponent
        ContentItem {}
    }

    Loader {
        anchors.fill: parent
        active: picker.used
        sourceComponent: Component {
            ContentPeerPicker {
                handler: ContentHandler.Destination
                contentType: picker.hubType
                headerText: qsTr("Open or save with")

                onPeerSelected: {
                    var transfer = peer.request()
                    var item = itemComponent.createObject(picker,
                                                          { url: "file://" + picker.path })
                    transfer.items = [item]
                    transfer.state = ContentTransfer.Charged
                    picker.activeTransfer = transfer
                    picker.close()
                }
                onCancelPressed: picker.close()
            }
        }
    }
}
