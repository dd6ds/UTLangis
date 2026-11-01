import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One conversation: the messages (Signal.messages) and the input row with
// emoji, photo and voice message buttons. A picked photo is shown above the input
// until it is sent.
Page {
    id: page
    property var app
    // file:// URL of a photo waiting to be sent ("" = none).
    property string pendingPhoto: ""
    // The message the next one replies to ({ts, sender, text, senderName,
    // outgoing}), or null.
    property var replyTo: null
    // The emoji panel is shown instead of the keyboard.
    property bool emojiOpen: false

    function insertEmoji(emoji) {
        Qt.inputMethod.commit()
        messageField.insert(messageField.cursorPosition, emoji)
    }

    // Opening the keyboard (tapping the message field) closes the panel.
    Connections {
        target: Qt.inputMethod
        onVisibleChanged: {
            if (Qt.inputMethod.visible)
                page.emojiOpen = false
        }
    }

    background: Rectangle { color: page.app.colorBackground }

    readonly property bool muted: Notifications.mutedThreads.indexOf(Signal.currentThread) >= 0

    header: AppHeader {
        app: page.app
        title: Signal.currentTitle.length ? Signal.currentTitle : qsTr("Unknown contact")
        onBack: page.app.stack.pop()

        ToolButton {
            // Groups keep the name their members gave them.
            visible: Signal.currentThread.indexOf("c:") === 0
            text: "✎"
            font.pixelSize: page.app.fontTitle
            Accessible.name: qsTr("Rename")
            onClicked: renameDialog.open()
        }
        ToolButton {
            text: page.muted ? "🔕" : "🔔"
            font.pixelSize: page.app.fontTitle
            Accessible.name: page.muted ? qsTr("Unmute") : qsTr("Mute")
            onClicked: {
                Notifications.setMuted(Signal.currentThread, !page.muted)
                page.app.showNote(page.muted ? qsTr("Chat muted") : qsTr("Chat unmuted"))
            }
        }
    }

    // The quote a reply carries; an own message's author is left empty.
    function quoteOf(message) {
        if (!message)
            return {}
        return { ts: message.ts, author: message.outgoing ? "" : message.sender,
                 text: message.text, name: message.outgoing ? "" : message.senderName }
    }

    function startReply(message) {
        replyTo = message
        messageField.forceActiveFocus()
    }

    // The text typed so far, including a word the keyboard has not
    // committed yet (predictive input keeps it as pre-edit text).
    readonly property string typedText: (messageField.text + messageField.preeditText).trim()

    function send() {
        // Make the keyboard hand over a word it still holds back.
        Qt.inputMethod.commit()
        var text = messageField.text.trim()
        if (!text.length && !pendingPhoto.length)
            return
        Signal.sendMessage(text, pendingPhoto.length ? [pendingPhoto] : [], quoteOf(replyTo))
        messageField.text = ""
        pendingPhoto = ""
        replyTo = null
    }

    StackView.onRemoved: {
        page.emojiOpen = false
        Voice.cancelRecording()
        Voice.stopPlaying()
        Signal.closeThread()
    }

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
                onActionsRequested: actionsDialog.openFor({
                    ts: ts, outgoing: outgoing, sender: sender, text: text,
                    senderName: senderName.length ? senderName : Signal.currentTitle,
                    myReaction: reactions.me || "" })
            }
            onCountChanged: positionViewAtEnd()
            // The list gets shorter when the keyboard opens; keep the newest
            // messages in view.
            onHeightChanged: positionViewAtEnd()
        }

        // The message being replied to, above the input row.
        Rectangle {
            Layout.fillWidth: true
            visible: page.replyTo !== null
            implicitHeight: replyRow.implicitHeight + page.app.gu
            color: page.app.colorSurface

            RowLayout {
                id: replyRow
                anchors.verticalCenter: parent.verticalCenter
                x: page.app.gu
                width: parent.width - 2 * page.app.gu
                spacing: page.app.gu

                QuoteView {
                    Layout.fillWidth: true
                    app: page.app
                    author: page.replyTo ? (page.replyTo.outgoing ? qsTr("You")
                                                                 : page.replyTo.senderName) : ""
                    quotedText: page.replyTo ? page.replyTo.text : ""
                    textColor: page.app.colorText
                }
                ToolButton {
                    text: "✕"
                    Accessible.name: qsTr("Cancel reply")
                    onClicked: page.replyTo = null
                }
            }
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
            visible: !Voice.recording

            ToolButton {
                text: "📎"
                font.pixelSize: page.app.fontTitle
                Accessible.name: qsTr("Attach photo")
                onClicked: importPicker.open()
            }
            ToolButton {
                text: page.emojiOpen ? "⌨" : "😊"
                font.pixelSize: page.app.fontTitle
                Accessible.name: page.emojiOpen ? qsTr("Keyboard") : qsTr("Emoji")
                onClicked: {
                    if (page.emojiOpen) {
                        page.emojiOpen = false
                        messageField.forceActiveFocus()
                        Qt.inputMethod.show()
                    } else {
                        Qt.inputMethod.hide()
                        page.emojiOpen = true
                    }
                }
            }
            ToolButton {
                text: "🎤"
                font.pixelSize: page.app.fontTitle
                enabled: !Signal.busy
                Accessible.name: qsTr("Record voice message")
                onClicked: Voice.startRecording()
            }
            AppField {
                id: messageField
                Layout.fillWidth: true
                placeholderText: qsTr("Message")
                onAccepted: page.send()
            }
            Button {
                enabled: !Signal.busy && (page.typedText.length > 0
                                          || page.pendingPhoto.length > 0)
                text: Signal.busy ? "…" : qsTr("Send")
                onClicked: page.send()
            }
        }

        // Shown instead of the input row while a voice message is recorded.
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: page.app.gu
            spacing: page.app.gu
            visible: Voice.recording

            ToolButton {
                text: "✕"
                font.pixelSize: page.app.fontTitle
                Accessible.name: qsTr("Discard recording")
                onClicked: Voice.cancelRecording()
            }
            Rectangle {
                implicitWidth: page.app.gu
                implicitHeight: implicitWidth
                radius: width / 2
                color: page.app.colorError
            }
            AppLabel {
                Layout.fillWidth: true
                text: qsTr("Recording %1").arg(page.app.durationText(Voice.recordedMs))
            }
            Button {
                text: qsTr("Send")
                onClicked: {
                    var url = Voice.stopRecording()
                    if (url.length)
                        Signal.sendVoiceNote(url)
                    else
                        page.app.showNote(qsTr("Recording too short"))
                }
            }
        }

        EmojiPicker {
            Layout.fillWidth: true
            Layout.preferredHeight: page.app.gu * 24
            visible: page.emojiOpen && !Voice.recording
            app: page.app
            onPicked: page.insertEmoji(emoji)
        }
    }

    RenameDialog {
        id: renameDialog
        app: page.app
    }

    MessageActionsDialog {
        id: actionsDialog
        app: page.app
        onReplyRequested: page.startReply(message)
    }

    ImportPicker {
        id: importPicker
        onImported: page.pendingPhoto = url
    }
}
