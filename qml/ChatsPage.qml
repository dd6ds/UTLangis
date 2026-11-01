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
        title: "ubSignal"
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
            text: "+"
            font.pixelSize: page.app.fontTitle
            Accessible.name: qsTr("New chat")
            onClicked: newChatDialog.open()
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
        text: qsTr("No chats yet. Tap + to write to a phone number.")
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
