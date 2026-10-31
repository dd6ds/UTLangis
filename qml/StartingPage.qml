import QtQuick 2.12
import QtQuick.Controls 2.12

// Shown while the backend opens its database, until it reports whether an
// account is registered.
Page {
    id: page
    property var app

    background: Rectangle { color: page.app.colorBackground }

    Column {
        anchors.centerIn: parent
        width: parent.width - 4 * page.app.spacingUnit
        spacing: page.app.spacingUnit

        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: page.visible
        }

        AppLabel {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr("Starting...")
        }
    }
}
