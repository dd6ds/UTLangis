import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Settings: the registered number, the profile name, contacts access, the
// language and the light/dark appearance, plus a note on running in the background.
Page {
    id: page
    property var app

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: qsTr("Settings")
        onBack: page.app.stack.pop()
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 2 * page.app.spacingUnit
        clip: true

        ColumnLayout {
            id: content
            x: page.app.spacingUnit
            y: page.app.spacingUnit
            width: parent.width - 2 * page.app.spacingUnit
            spacing: page.app.spacingUnit * 1.5

            AppLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("Registered number: %1").arg(Signal.phone)
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("Change profile name")
                onClicked: profileDialog.open()
            }

            // Turning this on here is the user's explicit permission, like
            // "Allow" in ContactsConsentDialog.
            Switch {
                id: contactsSwitch
                Layout.fillWidth: true
                text: qsTr("Allow access to contacts")
                checked: page.app.settings.contactsAccess === "allowed"
                onToggled: page.app.settings.contactsAccess = checked ? "allowed" : "denied"
                contentItem: AppLabel {
                    leftPadding: contactsSwitch.indicator.width + contactsSwitch.spacing
                    text: contactsSwitch.text
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            LanguageChoice {
                Layout.fillWidth: true
                app: page.app
            }

            AppearanceChoice {
                Layout.fillWidth: true
                app: page.app
            }

            AppLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: page.app.colorSecondaryText
                font.pixelSize: page.app.fontSecondary
                text: qsTr("Ubuntu Touch pauses apps in the background, so new messages "
                           + "arrive when ubSignal is open. To be notified while it is in "
                           + "the background, prevent app suspension for ubSignal "
                           + "(e.g. with UT Tweak Tool).")
            }
        }
    }

    ProfileDialog {
        id: profileDialog
        app: page.app
    }
}
