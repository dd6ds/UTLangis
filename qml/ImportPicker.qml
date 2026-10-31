import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Content 1.3

// Gets a photo from another app (gallery, file manager) through the Content
// Hub. The hub copies it into the app's HubIncoming folder and `imported`
// reports that copy.
Popup {
    id: picker
    property var activeTransfer: null

    signal imported(string url)

    parent: Overlay.overlay
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: true

    // Created on first use: it pulls in the Lomiri toolkit, which would
    // otherwise slow down the app start. It stays afterwards, so closing the
    // popup from its own signal handlers does not destroy it mid-handler.
    property bool used: false
    onOpened: used = true

    Loader {
        anchors.fill: parent
        active: picker.used
        sourceComponent: Component {
            ContentPeerPicker {
                handler: ContentHandler.Source
                contentType: ContentType.Pictures
                headerText: qsTr("Send a photo from")

                onPeerSelected: {
                    peer.selectionType = ContentTransfer.Single
                    picker.activeTransfer = peer.request()
                    picker.close()
                }
                onCancelPressed: picker.close()
            }
        }
    }

    Connections {
        target: picker.activeTransfer
        onStateChanged: {
            var transfer = picker.activeTransfer
            // The transfer reports one more change after it was dropped.
            if (!transfer)
                return
            if (transfer.state === ContentTransfer.Charged) {
                if (transfer.items.length)
                    picker.imported(String(transfer.items[0].url))
                picker.activeTransfer = null
            } else if (transfer.state === ContentTransfer.Aborted) {
                picker.activeTransfer = null
            }
        }
    }
}
