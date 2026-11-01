import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// User interface language: like the phone, or one fixed language. Each
// language is named in itself, so it can be found whatever is shown now.
ColumnLayout {
    id: choice
    property var app

    spacing: 0

    AppLabel {
        text: qsTr("Language")
        font.bold: true
        font.pixelSize: choice.app.fontSecondary
    }

    Repeater {
        model: [{ code: "", name: qsTr("Like the phone") }].concat(Language.uiLanguages)
        RadioButton {
            id: option
            text: modelData.name
            checked: Language.language === modelData.code
            onToggled: if (checked) Language.language = modelData.code
            contentItem: AppLabel {
                leftPadding: option.indicator.width + option.spacing
                text: option.text
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
