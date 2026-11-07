import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Conversation list, newest first. New chats are started by phone number.
// Right after registering, asks once for the profile name others will see.
Page {
    id: page
    property var app

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: "UT Langis"
        showBack: false

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: page.app.gu
            height: width
            radius: width / 2
            color: Signal.state === "online" ? page.app.colorSuccess : page.app.colorInactive
            Accessible.name: Signal.state === "online" ? qsTr("Connected") : qsTr("Not connected")
        }
        ToolButton {
            text: "⚙"
            font.pixelSize: page.app.fontTitle
            Accessible.name: qsTr("Settings")
            onClicked: page.app.openSettings()
        }
    }

    ListView {
        id: threadList
        anchors.fill: parent
        clip: true
        model: Signal.threads
        delegate: ThreadRow {
            width: threadList.width
            app: page.app
            onClicked: page.app.openChat(thread)
        }
    }

    AppLabel {
        anchors.centerIn: parent
        width: parent.width - 4 * page.app.spacingUnit
        visible: threadList.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: page.app.colorSecondaryText
        text: qsTr("No chats yet. Tap ✎ to start one.")
    }

    // New chat, round button at the bottom right as in Signal.
    RoundButton {
        id: newChatButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: page.app.spacingUnit * 1.5
        implicitWidth: page.app.gu * 7
        implicitHeight: implicitWidth
        text: "✎"
        font.pixelSize: page.app.fontTitle * 1.2
        palette.buttonText: "#ffffff"
        Accessible.name: qsTr("New chat")
        background: Rectangle {
            radius: width / 2
            color: newChatButton.down ? Qt.darker(page.app.colorAccent, 1.2)
                                      : page.app.colorAccent
            // A soft shadow below the button.
            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.topMargin: page.app.gu * 0.4
                radius: width / 2
                color: "#40000000"
            }
        }
        onClicked: newChatDialog.open()
    }

    NewChatDialog {
        id: newChatDialog
        app: page.app
    }

    ProfileDialog {
        id: profileDialog
        app: page.app
    }

    Connections {
        target: Signal
        onChatStarted: {
            newChatDialog.close()
            // The chat may have been started from the contact picker.
            page.app.stack.pop(page)
            page.app.openChat(thread)
        }
    }

    Component.onCompleted: {
        // A linked device uses the profile of its account.
        if (!page.app.settings.profileAsked && !Signal.linked) {
            page.app.settings.profileAsked = true
            profileDialog.open()
        }
    }
}
