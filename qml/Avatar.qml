import QtQuick 2.12

// Round picture of a contact or group, as in Signal: the initials on a
// soft colour that is always the same for the same chat.
Rectangle {
    id: avatar
    property var app
    // Name to take the initials from.
    property string name: ""
    // Picks the colour (the chat's key).
    property string colorKey: name
    property bool group: false
    property real size: app.gu * 5.5

    // Signal's avatar colours: background and text, light and dark theme.
    readonly property var palettes: [
        ["#e3e3fe", "#3838f5"], ["#dde7fc", "#1251d3"], ["#d8e8f0", "#086da0"],
        ["#cde4cd", "#067906"], ["#eae0f8", "#661aff"], ["#f5e3fe", "#9f00f0"],
        ["#f6d8ec", "#b8057c"], ["#f5d7d7", "#be0404"], ["#fef5d0", "#836b01"],
        ["#eae6d5", "#7d6f40"], ["#d2d2dc", "#4f4f6d"], ["#d7d7d9", "#5c5c5c"]
    ]
    readonly property var colors: {
        var hash = 0
        for (var i = 0; i < colorKey.length; ++i)
            hash = (hash * 31 + colorKey.charCodeAt(i)) % 1000003
        return palettes[hash % palettes.length]
    }

    readonly property string initials: {
        var words = name.trim().split(/\s+/).filter(function (w) {
            return w.length > 0 && /[A-Za-zÀ-ɏͰ-ϿЀ-ӿ]/.test(w.charAt(0))
        })
        if (words.length === 0)
            return ""
        var first = words[0].charAt(0)
        var second = words.length > 1 ? words[words.length - 1].charAt(0) : ""
        return (first + second).toUpperCase()
    }

    width: size
    height: size
    radius: size / 2
    color: app.darkMode ? colors[1] : colors[0]

    Text {
        anchors.centerIn: parent
        text: avatar.initials.length ? avatar.initials : (avatar.group ? "👥" : "👤")
        color: avatar.app.darkMode ? avatar.colors[0] : avatar.colors[1]
        font.pixelSize: avatar.initials.length ? avatar.size * 0.38 : avatar.size * 0.45
        font.weight: Font.DemiBold
    }
}
