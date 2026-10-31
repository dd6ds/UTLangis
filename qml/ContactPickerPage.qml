import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtContacts 5.0

// Address book contacts, one row per phone number, filtered by a search
// field. Tapping a row starts a chat with that number; ChatsPage then
// replaces this page with the chat. Only opened after the user allowed
// access (ContactsConsentDialog).
Page {
    id: page
    property var app

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: qsTr("Contacts")
        onBack: page.app.stack.pop()
    }

    // The contacts' detail objects are owned by ContactModel and change while
    // it fetches, so the rows copy plain name/number strings instead of
    // holding on to them.
    function rebuild() {
        entries.clear()
        var query = searchField.text.trim().toLowerCase()
        var contacts = contactModel.contacts
        for (var i = 0; i < contacts.length; ++i) {
            var name = contacts[i].displayLabel.label
            var numbers = contacts[i].phoneNumbers
            for (var j = 0; j < numbers.length; ++j) {
                var number = numbers[j].number
                if (!query.length || name.toLowerCase().indexOf(query) >= 0
                        || number.replace(/\s/g, "").indexOf(query) >= 0)
                    entries.append({ name: name, number: number })
            }
        }
    }

    ListModel { id: entries }

    // "galera" is the Ubuntu Touch address book service.
    ContactModel {
        id: contactModel
        manager: "galera"
        autoUpdate: true
        sortOrders: SortOrder {
            detail: ContactDetail.DisplayLabel
            field: DisplayLabel.Label
        }
        fetchHint: FetchHint {
            detailTypesHint: [ContactDetail.DisplayLabel, ContactDetail.PhoneNumber]
        }
        onContactsChanged: page.rebuild()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        AppField {
            id: searchField
            Layout.fillWidth: true
            Layout.margins: page.app.gu
            placeholderText: qsTr("Search")
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextChanged: page.rebuild()
        }

        ListView {
            id: contactList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: entries
            delegate: ItemDelegate {
                id: entryRow
                width: contactList.width
                padding: page.app.spacingUnit
                enabled: !Signal.busy
                onClicked: Signal.startChat(model.number, model.name)

                background: Rectangle {
                    color: entryRow.pressed ? page.app.colorSurfacePressed : "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: page.app.colorBorder
                    }
                }

                contentItem: ColumnLayout {
                    spacing: page.app.gu * 0.3
                    AppLabel {
                        Layout.fillWidth: true
                        text: model.name
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    AppLabel {
                        Layout.fillWidth: true
                        text: model.number
                        color: page.app.colorSecondaryText
                        font.pixelSize: page.app.fontSecondary
                    }
                }
            }
        }
    }

    AppLabel {
        anchors.centerIn: parent
        width: parent.width - 4 * page.app.spacingUnit
        visible: contactList.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: page.app.colorSecondaryText
        text: qsTr("No contacts found.")
    }

    BusyIndicator {
        anchors.centerIn: parent
        visible: Signal.busy
        running: visible
    }
}
