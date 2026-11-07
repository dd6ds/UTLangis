import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A loudness setting in dB: title with the value as a badge, a thick slider
// between − and + buttons, "quieter … louder" below (as in utDMR).
ColumnLayout {
    id: control
    property var app
    property string title
    property int value: 0
    property int from: 0
    property int to: 20

    // The user asked for this value.
    signal valueRequested(int value)

    spacing: app.gu * 0.6

    function dbText(db) {
        return (db > 0 ? "+" : db < 0 ? "−" : "") + Math.abs(Math.round(db)) + " dB"
    }

    function set(db) {
        control.valueRequested(Math.max(control.from, Math.min(control.to, db)))
    }

    RowLayout {
        Layout.fillWidth: true
        AppLabel {
            Layout.fillWidth: true
            text: control.title
            font.bold: true
            wrapMode: Text.Wrap
        }
        Rectangle {
            implicitWidth: valueLabel.implicitWidth + control.app.gu * 1.6
            implicitHeight: valueLabel.implicitHeight + control.app.gu * 0.6
            radius: height / 2
            color: control.app.colorAccent
            AppLabel {
                id: valueLabel
                anchors.centerIn: parent
                text: control.dbText(control.value)
                color: "#ffffff"
                font.bold: true
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: control.app.gu * 0.6

        RoundButton {
            text: "−"
            font.pixelSize: control.app.fontTitle
            font.bold: true
            enabled: control.value > control.from
            autoRepeat: true
            Accessible.name: qsTr("Quieter")
            onClicked: control.set(control.value - 1)
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: control.from
            to: control.to
            stepSize: 1
            snapMode: Slider.SnapAlways
            value: control.value
            onMoved: control.set(value)
            implicitHeight: control.app.gu * 4.5

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: control.app.gu * 1.2
                radius: height / 2
                color: control.app.colorSurface
                border.color: control.app.colorBorder
                border.width: 1

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: control.app.colorAccent
                }
                // Mark at 0 dB (unchanged), when it lies inside the range.
                Rectangle {
                    visible: control.from < 0 && control.to > 0
                    x: parent.width * (0 - control.from) / (control.to - control.from)
                    width: 2
                    height: parent.height + control.app.gu
                    anchors.verticalCenter: parent.verticalCenter
                    color: control.app.colorSecondaryText
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: control.app.gu * 3.6
                height: width
                radius: width / 2
                color: slider.pressed ? Qt.darker(control.app.colorAccent, 1.2)
                                      : control.app.colorAccent
                border.color: "#ffffff"
                border.width: control.app.gu * 0.35
            }
        }

        RoundButton {
            text: "+"
            font.pixelSize: control.app.fontTitle
            font.bold: true
            enabled: control.value < control.to
            autoRepeat: true
            Accessible.name: qsTr("Louder")
            onClicked: control.set(control.value + 1)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        AppLabel {
            text: qsTr("quieter")
            font.pixelSize: control.app.fontSecondary
            color: control.app.colorSecondaryText
        }
        Item { Layout.fillWidth: true }
        AppLabel {
            text: qsTr("louder")
            font.pixelSize: control.app.fontSecondary
            color: control.app.colorSecondaryText
        }
    }
}
