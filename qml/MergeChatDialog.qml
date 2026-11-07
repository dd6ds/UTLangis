import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// For a chat started with a phone number: when the person's replies landed
// in a second chat, the user picks that chat and both become one.
Dialog {
    id: dialog
    property var app

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    height: Math.min(parent.height * 0.8, implicitHeight)
    modal: true
    title: qsTr("Join with another chat")
    standardButtons: Dialog.Cancel

    ColumnLayout {
        anchors.fill: parent
        spacing: dialog.app.spacingUnit

        AppLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: dialog.app.colorSecondaryText
            font.pixelSize: dialog.app.fontSecondary
            text: qsTr("This chat was started with a phone number. If the person's replies "
                       + "appear in another chat, pick it: both chats become one.")
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            clip: true
            model: Signal.threads

            delegate: ItemDelegate {
                // Only other one-to-one chats with an account id.
                readonly property bool offered: thread !== Signal.currentThread
                                                && thread.indexOf("c:") === 0
                                                && thread.indexOf("c:PNI:") !== 0
                width: list.width
                height: offered ? implicitHeight : 0
                visible: offered
                contentItem: RowLayout {
                    spacing: dialog.app.spacingUnit
                    Avatar {
                        app: dialog.app
                        size: dialog.app.gu * 4
                        name: title
                        colorKey: thread
                    }
                    AppLabel {
                        Layout.fillWidth: true
                        text: title.length ? title : qsTr("Unknown contact")
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }
                onClicked: {
                    Signal.mergeChats(Signal.currentThread, thread)
                    dialog.close()
                }
            }
        }
    }
}
