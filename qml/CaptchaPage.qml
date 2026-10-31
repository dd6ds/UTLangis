import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtWebEngine 1.7

// Signal's registration captcha. When it is solved, the page shows an
// "Open Signal" link to signalcaptcha://<token>. QtWebEngine hands such
// unknown schemes to the system instead of reporting a navigation, so the
// page is checked for that link once a second and its token handed to
// `deliver`. The field below takes such a link pasted from a browser, in case
// the captcha does not work in this view.
Page {
    id: page
    property var app
    // Called with the signalcaptcha:// link once the captcha is solved.
    property var deliver

    readonly property string captchaUrl:
        "https://signalcaptchas.org/registration/generate.html"
    readonly property string tokenScheme: "signalcaptcha://"

    background: Rectangle { color: page.app.colorBackground }

    header: AppHeader {
        app: page.app
        title: qsTr("Captcha")
        onBack: page.app.stack.pop()
    }

    // Returns the href of the token link, or "" while it is not there.
    readonly property string findTokenLink:
        "(function() { var a = document.querySelector('a[href^=\"signalcaptcha:\"]');"
        + " return a ? a.href : ''; })()"

    property bool finished: false

    function finish(link) {
        if (finished)
            return
        finished = true
        page.app.stack.pop()
        page.deliver(link)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        WebEngineView {
            id: webView
            Layout.fillWidth: true
            Layout.fillHeight: true
            url: page.captchaUrl
            onNavigationRequested: {
                var target = String(request.url)
                if (target.indexOf(page.tokenScheme) === 0) {
                    request.action = WebEngineNavigationRequest.IgnoreRequest
                    page.finish(target)
                }
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: !page.finished && !webView.loading
            onTriggered: webView.runJavaScript(page.findTokenLink, function(link) {
                if (link && String(link).indexOf(page.tokenScheme) === 0)
                    page.finish(String(link))
            })
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: page.app.gu
            spacing: page.app.gu

            AppField {
                id: linkField
                Layout.fillWidth: true
                placeholderText: qsTr("or paste the signalcaptcha:// link")
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
            }

            Button {
                enabled: linkField.text.trim().indexOf(page.tokenScheme) === 0
                text: qsTr("OK")
                onClicked: page.finish(linkField.text.trim())
            }
        }
    }
}
