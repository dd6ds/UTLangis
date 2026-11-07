import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// One conversation: the messages (Signal.messages), oldest at the top, and
// the input row with emoji, photo and voice message buttons. A picked photo,
// the message being replied to or the one being changed is shown above the
// input.
Page {
    id: page
    objectName: "chatPage"
    property var app
    // file:// URL of a photo waiting to be sent ("" = none).
    property string pendingPhoto: ""
    // file:// URL of a recorded voice message waiting to be sent ("" = none).
    property string recordedVoice: ""
    // The message the next one replies to ({ts, sender, text, senderName,
    // outgoing}), or null.
    property var replyTo: null
    // Own message whose text is being changed ({ts, text}), or null.
    property var editing: null
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
        avatarKey: Signal.currentThread
        groupAvatar: Signal.currentThread.indexOf("c:") !== 0
        onBack: page.app.stack.pop()

        ToolButton {
            // Calls with one person (not groups).
            visible: Calls.available && Signal.currentThread.indexOf("c:") === 0
            text: "📞"
            font.pixelSize: page.app.fontTitle
            Accessible.name: qsTr("Call")
            onClicked: Calls.startCall(Signal.currentThread, Signal.currentTitle, false)
        }
        ToolButton {
            visible: Calls.available && Signal.currentThread.indexOf("c:") === 0
            text: "🎥"
            font.pixelSize: page.app.fontTitle
            Accessible.name: qsTr("Video call")
            onClicked: Calls.startCall(Signal.currentThread, Signal.currentTitle, true)
        }
        ToolButton {
            // Chats started with a phone number can be joined with the
            // chat the person's replies went to.
            visible: Signal.currentThread.indexOf("c:PNI:") === 0
            text: "⇄"
            font.pixelSize: page.app.fontTitle
            Accessible.name: qsTr("Join with another chat")
            onClicked: mergeDialog.open()
        }
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
        editing = null
        replyTo = message
        messageField.forceActiveFocus()
    }

    // Puts the message's text into the input field; sending then changes
    // the message instead of sending a new one.
    function startEdit(message) {
        replyTo = null
        pendingPhoto = ""
        editing = { ts: message.ts, text: message.text }
        messageField.text = message.text
        messageField.forceActiveFocus()
        messageField.cursorPosition = messageField.length
    }

    function cancelReplyOrEdit() {
        if (editing)
            messageField.text = ""
        replyTo = null
        editing = null
    }

    // The text typed so far, including a word the keyboard has not
    // committed yet (predictive input keeps it as pre-edit text).
    readonly property string typedText: (messageField.text + messageField.preeditText).trim()

    function send() {
        // Make the keyboard hand over a word it still holds back.
        Qt.inputMethod.commit()
        var text = messageField.text.trim()
        if (editing) {
            if (text.length && text !== editing.text)
                Signal.editMessage(editing.ts, text)
            messageField.text = ""
            editing = null
            return
        }
        if (!text.length && !pendingPhoto.length)
            return
        Signal.sendMessage(text, pendingPhoto.length ? [pendingPhoto] : [], quoteOf(replyTo))
        messageField.text = ""
        pendingPhoto = ""
        replyTo = null
    }

    // Removes the recorded voice message that was not sent.
    function discardVoice() {
        Voice.stopPlaying()
        Voice.cancelRecording()
        recordedVoice = ""
    }

    StackView.onRemoved: {
        page.emojiOpen = false
        if (page.recordedVoice.length)
            page.discardVoice()
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
            // Calls are rows of their own, messages are bubbles. The
            // components are declared inside the delegate so they see its
            // model roles.
            delegate: Column {
                width: messageList.width
                spacing: page.app.gu * 0.6

                DayHeader {
                    width: parent.width
                    visible: index === 0
                             || !page.app.sameDay(ts, Signal.messages.tsAt(index - 1))
                    app: page.app
                    time: ts
                }

                Loader {
                    width: messageList.width
                    sourceComponent: call !== "" ? callComponent : bubbleComponent

                    Component {
                        id: callComponent
                        CallRow {
                            app: page.app
                            outcome: call
                            isVideo: video
                            time: ts
                        }
                    }
                    Component {
                        id: bubbleComponent
                        MessageBubble {
                            app: page.app
                            info: ({ ts: ts, outgoing: outgoing, sender: sender, text: text,
                                     senderName: senderName.length ? senderName
                                                                   : Signal.currentTitle,
                                     myReaction: reactions.me || "" })
                            onActionsRequested: actionsDialog.openFor(info)
                        }
                    }
                }
            }
            // After the delegates are laid out, so variable bubble heights
            // (quotes, photos) do not leave the newest message half hidden.
            onCountChanged: Qt.callLater(positionViewAtEnd)
            // The list gets shorter when the keyboard opens; keep the newest
            // messages in view.
            onHeightChanged: positionViewAtEnd()
        }

        // The message being replied to, above the input row.
        Rectangle {
            Layout.fillWidth: true
            visible: page.replyTo !== null || page.editing !== null
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
                    author: page.editing ? qsTr("Edit message")
                          : page.replyTo ? (page.replyTo.outgoing ? qsTr("You")
                                                                  : page.replyTo.senderName)
                          : ""
                    quotedText: page.editing ? page.editing.text
                              : page.replyTo ? page.replyTo.text : ""
                    textColor: page.app.colorText
                }
                ToolButton {
                    text: "✕"
                    Accessible.name: qsTr("Cancel reply")
                    onClicked: page.cancelReplyOrEdit()
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
            ToolButton {
                anchors.left: parent.left
                anchors.top: parent.top
                text: "✂"
                font.pixelSize: page.app.fontTitle
                Accessible.name: qsTr("Crop photo")
                onClicked: page.app.openCropper(page.pendingPhoto,
                                                function(url) { page.pendingPhoto = url })
            }
        }

        // Input bar as in Signal: a rounded field with the emoji and
        // attachment buttons, next to a round send button (microphone while
        // there is nothing to send).
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: page.app.gu
            spacing: page.app.gu
            visible: !Voice.recording && page.recordedVoice.length === 0

            readonly property bool canSend: page.typedText.length > 0
                                            || page.pendingPhoto.length > 0
                                            || page.editing !== null

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(page.app.gu * 5.5, inputRow.implicitHeight)
                radius: page.app.gu * 2.75
                color: page.app.colorSurface

                RowLayout {
                    id: inputRow
                    anchors.fill: parent
                    anchors.leftMargin: page.app.gu * 0.5
                    anchors.rightMargin: page.app.gu * 0.5
                    spacing: 0

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
                    AppField {
                        id: messageField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Message")
                        background: Item {}
                        onAccepted: page.send()
                    }
                    ToolButton {
                        text: "📎"
                        font.pixelSize: page.app.fontTitle
                        // An edit changes only the text.
                        enabled: page.editing === null
                        Accessible.name: qsTr("Attach photo")
                        onClicked: importPicker.open()
                    }
                    ToolButton {
                        text: "📷"
                        font.pixelSize: page.app.fontTitle
                        enabled: page.editing === null
                        Accessible.name: qsTr("Take photo")
                        onClicked: page.app.stack.push(Qt.resolvedUrl("ChatCameraPage.qml"),
                                                       { app: page.app })
                    }
                }
            }

            RoundButton {
                id: sendButton
                implicitWidth: page.app.gu * 5.5
                implicitHeight: implicitWidth
                enabled: !Signal.busy
                text: Signal.busy ? "…" : parent.canSend ? "➤" : "🎤"
                font.pixelSize: page.app.fontTitle
                Accessible.name: parent.canSend ? qsTr("Send") : qsTr("Record voice message")
                palette.buttonText: parent.canSend ? "#ffffff" : page.app.colorText
                background: Rectangle {
                    radius: width / 2
                    color: sendButton.parent.canSend
                           ? (sendButton.down ? Qt.darker(page.app.colorAccent, 1.2)
                                              : page.app.colorAccent)
                           : (sendButton.down ? page.app.colorSurfacePressed
                                              : page.app.colorSurface)
                }
                onClicked: {
                    if (parent.canSend)
                        page.send()
                    else
                        Voice.startRecording()
                }
            }
        }

        VoiceRecorderBar {
            Layout.fillWidth: true
            app: page.app
            chat: page
        }

        EmojiPicker {
            Layout.fillWidth: true
            Layout.preferredHeight: page.app.gu * 24
            visible: page.emojiOpen && !Voice.recording && page.recordedVoice.length === 0
            app: page.app
            onPicked: page.insertEmoji(emoji)
        }
    }

    RenameDialog {
        id: renameDialog
        app: page.app
    }

    MergeChatDialog {
        id: mergeDialog
        app: page.app
    }

    MessageActionsDialog {
        id: actionsDialog
        app: page.app
        onReplyRequested: page.startReply(message)
        onEditRequested: page.startEdit(message)
    }

    ImportPicker {
        id: importPicker
        onImported: page.pendingPhoto = url
    }
}
