import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One conversation: the messages (Signal.messages) and the input row with a
// photo button. A picked photo is shown above the input until it is sent.
Page {
    id: page
    property var app
    // file:// URL of a photo waiting to be sent ("" = none).
    property string pendingPhoto: ""

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: Signal.currentTitle.length ? Signal.currentTitle : qsTr("Unknown contact")
        onBack: page.app.stack.pop()
    }

    function send() {
        var text = messageField.text.trim()
        if (!text.length && !pendingPhoto.length)
            return
        Signal.sendMessage(text, pendingPhoto.length ? [pendingPhoto] : [])
        messageField.text = ""
        pendingPhoto = ""
    }

    StackView.onRemoved: Signal.closeThread()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ListView {
            id: messageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: page.app.gu * 0.6
            topMargin: page.app.gu
            bottomMargin: page.app.gu
            model: Signal.messages
            delegate: MessageBubble {
                width: messageList.width
                app: page.app
            }
            onCountChanged: positionViewAtEnd()
            // The list gets shorter when the keyboard opens; keep the newest
            // messages in view.
            onHeightChanged: positionViewAtEnd()
        }

        Rectangle {
            Layout.fillWidth: true
            visible: page.pendingPhoto.length > 0
            implicitHeight: page.app.gu * 10
            color: page.app.colorSurface

            Image {
                anchors.fill: parent
                anchors.margins: page.app.gu
                source: page.pendingPhoto
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.height: page.app.gu * 20
            }
            ToolButton {
                anchors.right: parent.right
                anchors.top: parent.top
                text: "✕"
                Accessible.name: qsTr("Remove photo")
                onClicked: page.pendingPhoto = ""
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: page.app.gu
            spacing: page.app.gu

            ToolButton {
                text: "📎"
                font.pixelSize: page.app.fontTitle
                Accessible.name: qsTr("Attach photo")
                onClicked: importPicker.open()
            }
            AppField {
                id: messageField
                Layout.fillWidth: true
                placeholderText: qsTr("Message")
                onAccepted: page.send()
            }
            Button {
                enabled: !Signal.busy && (messageField.text.trim().length > 0
                                          || page.pendingPhoto.length > 0)
                text: Signal.busy ? "…" : qsTr("Send")
                onClicked: page.send()
            }
        }
    }

    ImportPicker {
        id: importPicker
        onImported: page.pendingPhoto = url
    }
}
