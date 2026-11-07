import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Shown while someone calls us: answer (when the call library is there),
// decline, or leave it ringing to answer it on another device (e.g. Signal
// Desktop). Closes by itself when the call stops ringing.
Dialog {
    id: dialog
    property var app
    property string callId: ""
    property string thread: ""
    property string caller: ""
    property bool isVideo: false

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: parent.width * 0.9
    modal: true
    closePolicy: Popup.NoAutoClose
    title: isVideo ? qsTr("Incoming video call") : qsTr("Incoming call")

    Connections {
        target: Signal
        onIncomingCall: {
            dialog.callId = callId
            dialog.thread = thread
            dialog.caller = title
            dialog.isVideo = video
            dialog.open()
        }
        onCallEnded: {
            if (callId === dialog.callId)
                dialog.close()
        }
    }

    ColumnLayout {
        width: dialog.availableWidth
        spacing: dialog.app.spacingUnit

        AppLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.bold: true
            font.pixelSize: dialog.app.fontTitle
            text: (dialog.isVideo ? "🎥 " : "📞 ") + dialog.caller
        }

        AppLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: dialog.app.colorSecondaryText
            font.pixelSize: dialog.app.fontSecondary
            visible: !Calls.available
            text: qsTr("UT Langis cannot answer calls yet. Answer it on another device "
                       + "(e.g. Signal Desktop) or decline it.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: dialog.app.spacingUnit

            Button {
                Layout.fillWidth: true
                text: qsTr("Decline")
                palette.button: dialog.app.colorError
                palette.buttonText: "#ffffff"
                onClicked: {
                    if (Calls.available)
                        Calls.hangup()
                    else
                        Signal.declineCall(dialog.callId)
                    dialog.close()
                }
            }
            Button {
                Layout.fillWidth: true
                visible: Calls.available
                text: qsTr("Answer")
                palette.button: dialog.app.colorSuccess
                palette.buttonText: "#ffffff"
                onClicked: {
                    Calls.accept()
                    dialog.close()
                }
            }
            Button {
                Layout.fillWidth: true
                visible: !Calls.available
                text: qsTr("Let it ring")
                onClicked: {
                    Calls.stopRinging()
                    dialog.close()
                }
            }
        }
    }
}
