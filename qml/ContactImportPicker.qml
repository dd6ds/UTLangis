import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Content 1.3

// Lets the user pick one contact in the phone's Contacts app through the
// Content Hub. The app gets only that contact, as a vCard in its HubIncoming
// folder, so it needs no access to the address book itself. `imported`
// reports the file's URL.
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
                contentType: ContentType.Contacts
                headerText: qsTr("Choose a contact from")

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
