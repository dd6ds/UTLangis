import QtQuick 2.12

// Microphone level while recording: green while the voice is well recorded,
// yellow when it gets loud, red near distortion. Fed with Voice.levelDb.
Rectangle {
    id: meter
    property var app
    // Peak level in dBFS, -60 (silence) … 0 (full scale).
    property real levelDb: -60

    readonly property real fraction: Math.max(0, Math.min(1, (levelDb + 60) / 60))

    implicitHeight: app.gu * 0.8
    radius: height / 2
    color: app.colorSurface

    Rectangle {
        width: meter.width * meter.fraction
        height: parent.height
        radius: parent.radius
        color: meter.levelDb > -3 ? meter.app.colorError
             : meter.levelDb > -12 ? "#f9a825" : meter.app.colorSuccess
        Behavior on width { NumberAnimation { duration: 90 } }
    }
}
