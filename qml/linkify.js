.pragma library

// Web addresses in message text, for tappable links. Stops at white space
// and at characters that rarely end an address but often follow one.
var urlPattern = /(?:https?:\/\/|www\.)[^\s<>"]+/gi
var trailing = /[.,;:!?'")\]}]+$/

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
               .replace(/"/g, "&quot;")
}

function hasLink(text) {
    urlPattern.lastIndex = 0
    return urlPattern.test(text)
}

// The text as Qt "StyledText" with every web address as a link; everything
// else is escaped, so the message is shown exactly as written.
function toStyledText(text) {
    var result = ""
    var last = 0
    var match
    urlPattern.lastIndex = 0
    while ((match = urlPattern.exec(text)) !== null) {
        var address = match[0]
        var cut = address.match(trailing)
        if (cut)
            address = address.slice(0, address.length - cut[0].length)
        if (address.length === 0)
            continue
        var target = /^www\./i.test(address) ? "https://" + address : address
        result += escapeHtml(text.slice(last, match.index))
        // Qt's StyledText takes the href as written (no entities); the
        // pattern already excludes quotes and angle brackets.
        result += "<a href=\"" + target + "\">" + escapeHtml(address) + "</a>"
        last = match.index + address.length
        urlPattern.lastIndex = last
    }
    result += escapeHtml(text.slice(last))
    return result.replace(/\n/g, "<br>")
}
