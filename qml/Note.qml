import QtQuick 2.12

// Short note at the bottom of the window ("Saved as ...", errors), hidden
// again after a few seconds or on tap.
Rectangle {
    id: note
    property var app
    readonly property int showMs: 4000

    function show(text) {
        noteText.text = text
        visible = true
        hideTimer.restart()
    }

    visible: false
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: app.gu * 8
    width: Math.min(parent.width - 2 * app.spacingUnit, noteText.implicitWidth + 2 * app.spacingUnit)
    height: noteText.implicitHeight + app.spacingUnit
    radius: app.gu
    color: app.darkMode ? "#e0e0e0" : "#323232"

    Text {
        id: noteText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, note.parent.width - 4 * note.app.spacingUnit)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: note.app.darkMode ? "#111111" : "#ffffff"
        font.pixelSize: note.app.fontSecondary
    }

    Timer {
        id: hideTimer
        interval: note.showMs
        onTriggered: note.visible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: note.visible = false
    }
}
