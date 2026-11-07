import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Voice messages in the chat's input area: while recording, the time, the
// microphone level and buttons to discard or stop; afterwards, play the
// recording, then send or discard it. Both rows hide while not needed.
ColumnLayout {
    id: bar
    property var app
    // The ChatPage: holds the finished recording (recordedVoice).
    property var chat

    spacing: 0

    // Shown instead of the input row while a voice message is recorded:
    // discard it, or stop to listen to it first.
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: bar.app.gu
        spacing: bar.app.gu
        visible: Voice.recording

        ToolButton {
            text: "🗑"
            font.pixelSize: bar.app.fontTitle
            Accessible.name: qsTr("Discard recording")
            onClicked: Voice.cancelRecording()
        }
        Rectangle {
            implicitWidth: bar.app.gu
            implicitHeight: implicitWidth
            radius: width / 2
            color: bar.app.colorError
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: bar.app.gu * 0.4

            AppLabel {
                Layout.fillWidth: true
                text: qsTr("Recording %1").arg(bar.app.durationText(Voice.recordedMs))
            }
            LevelMeter {
                Layout.fillWidth: true
                app: bar.app
                levelDb: Voice.levelDb
            }
        }
        RoundButton {
            implicitWidth: bar.app.gu * 5.5
            implicitHeight: implicitWidth
            text: "■"
            font.pixelSize: bar.app.fontTitle
            Accessible.name: qsTr("Stop recording")
            onClicked: {
                var url = Voice.stopRecording()
                if (url.length)
                    bar.chat.recordedVoice = url
                else
                    bar.app.showNote(qsTr("Recording too short"))
            }
        }
    }

    // A finished recording: listen to it, then send or discard it.
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: bar.app.gu
        spacing: bar.app.gu
        visible: bar.chat.recordedVoice.length > 0 && !Voice.recording

        readonly property string path: bar.chat.recordedVoice.replace(/^file:\/\//, "")
        readonly property bool playing: Voice.playingPath === path

        ToolButton {
            text: "🗑"
            font.pixelSize: bar.app.fontTitle
            Accessible.name: qsTr("Discard recording")
            onClicked: bar.chat.discardVoice()
        }
        ToolButton {
            text: parent.playing ? "■" : "▶"
            font.pixelSize: bar.app.fontTitle
            Accessible.name: parent.playing ? qsTr("Stop") : qsTr("Listen to recording")
            onClicked: Voice.togglePlay(parent.path)
        }
        ProgressBar {
            Layout.fillWidth: true
            from: 0
            to: Math.max(1, Voice.durationMs)
            value: parent.playing ? Voice.positionMs : 0
        }
        AppLabel {
            font.pixelSize: bar.app.fontSecondary
            text: parent.playing ? bar.app.durationText(Voice.positionMs) : "🎤"
        }
        RoundButton {
            id: voiceSend
            implicitWidth: bar.app.gu * 5.5
            implicitHeight: implicitWidth
            enabled: !Signal.busy
            text: Signal.busy ? "…" : "➤"
            font.pixelSize: bar.app.fontTitle
            palette.buttonText: "#ffffff"
            Accessible.name: qsTr("Send")
            background: Rectangle {
                radius: width / 2
                color: voiceSend.down ? Qt.darker(bar.app.colorAccent, 1.2)
                                      : bar.app.colorAccent
            }
            onClicked: {
                Voice.stopPlaying()
                Signal.sendVoiceNote(bar.chat.recordedVoice)
                bar.chat.recordedVoice = ""
            }
        }
    }
}
