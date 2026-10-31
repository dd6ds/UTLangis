// Ubuntu Touch 20.04 ships Qt 5.12 - importing 2.15 makes the whole file fail
// to load. 2.12 is the highest version actually available on the device.
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12
import Qt.labs.settings 1.0

// Application window: scaling, colours, settings, the page stack and the
// switch between registration and chats. The pages live in their own files
// and get this window as `app`.
ApplicationWindow {
    id: rootWindow
    visible: true
    width: Screen.width
    height: Screen.height
    title: "ubSignal"
    color: colorBackground

    // --- Scaling -----------------------------------------------------------
    readonly property real gu: gridUnitPx
    readonly property int fontTitle:     Math.round(gu * 2.0)
    readonly property int fontBody:      Math.round(gu * 1.6)
    readonly property int fontSecondary: Math.round(gu * 1.3)
    readonly property int spacingUnit:   Math.round(gu * 1.5)

    font.pixelSize: fontBody

    // --- On-screen keyboard ------------------------------------------------
    // Lomiri does not shrink the window when the keyboard opens; it covers
    // the lower part instead. The pages are kept above it (StackView below),
    // so input fields at the bottom, like the chat's message field, stay
    // visible. The rectangle is reported in device pixels.
    readonly property real keyboardHeight: Qt.inputMethod.visible
        ? Qt.inputMethod.keyboardRectangle.height / Screen.devicePixelRatio : 0

    // --- Colours -----------------------------------------------------------
    // settings.themeMode: "system" follows the phone's Lomiri theme, "light"
    // and "dark" are fixed.
    readonly property bool darkMode: settings.themeMode === "dark"
                                     || (settings.themeMode === "system" && SystemTheme.dark)
    readonly property color colorBackground:      darkMode ? "#121212" : "#ffffff"
    readonly property color colorSurface:         darkMode ? "#1f2326" : "#f0f0f0"
    readonly property color colorSurfacePressed:  darkMode ? "#2d4a66" : "#b0d4ff"
    readonly property color colorFieldBackground: darkMode ? "#262a2d" : "#ffffff"
    readonly property color colorText:            darkMode ? "#eeeeee" : "#111111"
    readonly property color colorSecondaryText:   darkMode ? "#a8a8a8" : "#666666"
    readonly property color colorPlaceholder:     darkMode ? "#777777" : "#999999"
    readonly property color colorBorder:          darkMode ? "#4a4f53" : "#cccccc"
    readonly property color colorAccent:          darkMode ? "#5a8dee" : "#2c6bed"
    readonly property color colorSuccess:         darkMode ? "#66bb6a" : "#2e7d32"
    readonly property color colorError:           darkMode ? "#ef5350" : "#c62828"
    readonly property color colorInactive:        darkMode ? "#757575" : "#9e9e9e"
    readonly property color colorBubbleOwn:       darkMode ? "#2c4f8f" : "#2c6bed"
    readonly property color colorBubbleOwnText:   "#ffffff"
    readonly property color colorBubbleOther:     darkMode ? "#2a2e31" : "#e9e9eb"

    palette.window: colorBackground
    palette.windowText: colorText
    palette.base: colorFieldBackground
    palette.alternateBase: colorSurface
    palette.text: colorText
    palette.button: colorSurface
    palette.buttonText: colorText
    palette.brightText: "#ffffff"
    palette.highlight: colorAccent
    palette.highlightedText: "#ffffff"
    palette.light: darkMode ? "#2c3134" : "#f5f5f5"
    palette.midlight: darkMode ? "#33383b" : "#e0e0e0"
    palette.mid: colorBorder
    palette.dark: colorAccent
    palette.shadow: "#000000"

    Settings {
        id: settings
        property string themeMode: "system"
        // Last phone number typed on the registration page.
        property string phone: "+49"
        // Whether the user was asked for a profile name after registering.
        property bool profileAsked: false
        // Address book access: "ask" until the user answered
        // ContactsConsentDialog, then "allowed" or "denied".
        property string contactsAccess: "ask"
    }
    property alias settings: settings

    // --- Formatting --------------------------------------------------------
    // "hh:mm" for today, "dd.MM. hh:mm" for older messages. ts in ms.
    function timeText(ts) {
        if (!ts)
            return ""
        var d = new Date(ts)
        var today = new Date()
        today.setHours(0, 0, 0, 0)
        return Qt.formatDateTime(d, d.getTime() < today.getTime() ? "dd.MM. hh:mm" : "hh:mm")
    }

    // --- Navigation --------------------------------------------------------
    readonly property bool registered: Signal.state === "offline" || Signal.state === "online"

    function showRoot() {
        if (Signal.state === "starting")
            return
        var page = registered ? "ChatsPage.qml" : "RegisterPage.qml"
        if (stack.depth > 0 && stack.get(0).objectName === page)
            return
        stack.clear()
        stack.push(Qt.resolvedUrl(page), { app: rootWindow, objectName: page })
    }

    function openChat(thread) {
        Signal.openThread(thread)
        stack.push(Qt.resolvedUrl("ChatPage.qml"), { app: rootWindow })
    }

    // Opens the contact picker, asking for permission first if needed.
    function chooseContact() {
        if (settings.contactsAccess === "allowed")
            stack.push(Qt.resolvedUrl("ContactPickerPage.qml"), { app: rootWindow })
        else if (settings.contactsAccess === "ask")
            contactsConsent.open()
        else
            showNote(qsTr("Access to contacts is off. You can allow it in Settings."))
    }

    function openSettings() {
        stack.push(Qt.resolvedUrl("SettingsPage.qml"), { app: rootWindow })
    }

    function showNote(text) {
        note.show(text)
    }

    // Text for an error from the backend; `kind` codes are listed in
    // core/src (registration_error_kind, resolve).
    function errorText(kind, message) {
        switch (kind) {
        case "captchaRequired":
            return qsTr("Signal asks for a captcha. Please solve it again.")
        case "codeForbidden":
            return qsTr("Signal does not send a code right now. Try again later or ask for a call.")
        case "wrongCode":
            return qsTr("The code was not accepted. Please request a new one.")
        case "phoneNumber":
            return qsTr("Please enter the number in international format, e.g. +491701234567.")
        case "noAccount":
            return qsTr("This number does not use Signal.")
        default:
            return message
        }
    }

    // Registration errors are shown on the registration page itself.
    readonly property var pageErrorActions: ["register", "confirm"]

    Connections {
        target: Signal
        onStateChanged: rootWindow.showRoot()
        onProfileSet: rootWindow.showNote(qsTr("Profile name saved"))
        onErrorOccurred: {
            if (rootWindow.pageErrorActions.indexOf(action) < 0)
                rootWindow.showNote(rootWindow.errorText(kind, message))
        }
    }

    StackView {
        id: stack
        anchors.fill: parent
        anchors.bottomMargin: rootWindow.keyboardHeight
        initialItem: StartingPage { app: rootWindow }
    }
    property alias stack: stack

    ContactsConsentDialog {
        id: contactsConsent
        app: rootWindow
        onAllowed: rootWindow.chooseContact()
    }

    Note {
        id: note
        app: rootWindow
    }
}
