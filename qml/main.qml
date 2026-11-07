// Ubuntu Touch 20.04 ships Qt 5.12 - importing 2.15 makes the whole file fail
// to load. 2.12 is the highest version actually available on the device.
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12
import Qt.labs.settings 1.0
import QtSystemInfo 5.0

// Application window: scaling, colours, settings, the page stack and the
// switch between registration and chats. The pages live in their own files
// and get this window as `app`.
ApplicationWindow {
    id: rootWindow
    visible: true
    width: Screen.width
    height: Screen.height
    title: "UT Langis"
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
    // Close to Signal's own colours.
    readonly property color colorBackground:      darkMode ? "#121212" : "#ffffff"
    readonly property color colorSurface:         darkMode ? "#262626" : "#f2f2f4"
    readonly property color colorSurfacePressed:  darkMode ? "#2e3442" : "#e2e8f6"
    readonly property color colorFieldBackground: darkMode ? "#262626" : "#ffffff"
    readonly property color colorText:            darkMode ? "#e9e9e9" : "#1b1b1d"
    readonly property color colorSecondaryText:   darkMode ? "#a2a2a6" : "#5e5e62"
    readonly property color colorPlaceholder:     darkMode ? "#7a7a7e" : "#8e8e93"
    readonly property color colorBorder:          darkMode ? "#3a3a3c" : "#dcdce0"
    readonly property color colorAccent:          darkMode ? "#4f86f7" : "#2c6bed"
    readonly property color colorSuccess:         darkMode ? "#66bb6a" : "#2e7d32"
    readonly property color colorError:           darkMode ? "#ef5350" : "#c62828"
    readonly property color colorInactive:        darkMode ? "#757575" : "#9e9e9e"
    readonly property color colorBubbleOwn:       "#2c6bed"
    readonly property color colorBubbleOwnText:   "#ffffff"
    // Shown on own (blue) bubbles, so it has to stand out from them.
    readonly property color colorReadReceipt:     "#9cf09c"
    readonly property color colorBubbleOther:     darkMode ? "#303133" : "#e9e9eb"

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
        // Shutter click of the chat camera's and the QR scanner's photos.
        property bool shutterSound: true
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

    function sameDay(a, b) {
        var x = new Date(a)
        var y = new Date(b)
        return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth()
                && x.getDate() === y.getDate()
    }

    // "Today", "Yesterday", the weekday within a week, else the date.
    function dayText(ts) {
        var d = new Date(ts)
        d.setHours(0, 0, 0, 0)
        var today = new Date()
        today.setHours(0, 0, 0, 0)
        var days = Math.round((today.getTime() - d.getTime()) / 86400000)
        if (days === 0)
            return qsTr("Today")
        if (days === 1)
            return qsTr("Yesterday")
        if (days > 1 && days < 7)
            return d.toLocaleDateString(Qt.locale(), "dddd")
        return d.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    // "m:ss" for a length in milliseconds (voice messages).
    function durationText(ms) {
        var seconds = Math.floor(ms / 1000)
        var rest = seconds % 60
        return Math.floor(seconds / 60) + ":" + (rest < 10 ? "0" : "") + rest
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

    // Lets the user pick a contact in the Contacts app (ContactImportPicker);
    // the app itself has no access to the address book.
    function chooseContact() {
        contactImport.open()
    }

    // Starts a chat with a picked contact; one with several numbers asks
    // which one to use.
    function startChatWith(url) {
        var contact = Signal.readContactCard(url)
        if (!contact.numbers.length)
            showNote(qsTr("This contact has no phone number."))
        else if (contact.numbers.length === 1)
            Signal.startChat(contact.numbers[0], contact.name)
        else
            numberChoice.openFor(contact)
    }

    // The images of a message full screen, starting at `index`.
    function openImages(paths, index, message) {
        stack.push(Qt.resolvedUrl("ImageViewerPage.qml"),
                   { app: rootWindow, paths: paths, startIndex: index,
                     message: message || null })
    }

    // Back to the open chat, replying to `message`.
    function replyInChat(message) {
        var chat = stack.find(function(item) { return item.objectName === "chatPage" })
        if (!chat)
            return
        stack.pop(chat)
        chat.startReply(message)
    }

    // Crop page for the photo at `url`; `accept` gets the result's URL.
    function openCropper(url, accept) {
        stack.push(Qt.resolvedUrl("CropPage.qml"),
                   { app: rootWindow, source: url, accept: accept })
    }

    // Back to the open chat, with the photo at `url` waiting to be sent.
    function photoToChat(url) {
        var chat = stack.find(function(item) { return item.objectName === "chatPage" })
        if (!chat)
            return
        stack.pop(chat)
        chat.pendingPhoto = url
    }

    function openVideo(path, contentType, message) {
        stack.push(Qt.resolvedUrl("VideoPlayerPage.qml"),
                   { app: rootWindow, path: path, contentType: contentType,
                     message: message || null })
    }

    // Lets the user open or save a received file with another app.
    function exportFile(path, contentType) {
        exportPicker.exportFile(path, contentType)
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
        case "notLinkCode":
            return qsTr("This QR code is not a Signal code for linking a device.")
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

    Connections {
        target: Voice
        onFailed: rootWindow.showNote(qsTr("Audio could not be recorded or played: %1")
                                      .arg(message))
    }

    StackView {
        id: stack
        anchors.fill: parent
        anchors.bottomMargin: rootWindow.keyboardHeight
        initialItem: StartingPage { app: rootWindow }
    }
    property alias stack: stack

    ContactImportPicker {
        id: contactImport
        onImported: rootWindow.startChatWith(url)
    }

    NumberChoiceDialog {
        id: numberChoice
        app: rootWindow
    }

    IncomingCallDialog {
        app: rootWindow
    }

    ExportPicker {
        id: exportPicker
    }

    CallOverlay {
        anchors.fill: parent
        app: rootWindow
    }

    // The screen stays on while a call rings or runs: with the screen off,
    // Ubuntu Touch pauses the app and the call would break off.
    ScreenSaver {
        screenSaverEnabled: Calls.state === "" && !Calls.ringing
    }

    Note {
        id: note
        app: rootWindow
    }
}
