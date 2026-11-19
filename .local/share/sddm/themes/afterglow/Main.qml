import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#10141e"
    gradient: Gradient {
        GradientStop { position: 0; color: "#263858" }
        GradientStop { position: 1; color: "#10141e" }
    }
    property string errorText: ""
    property bool signingIn: false
    property bool showPassword: false
    property date now: new Date()
    function preferredSession() {
        const index = sessionModel.lastIndex
        return index >= 0 && index < session.count ? index : 0
    }
    function login() {
        if (signingIn) return
        if (!user.text.trim()) {
            errorText = "Enter your username."
            user.forceActiveFocus()
            return
        }
        if (!session.count) {
            errorText = "No desktop session is available."
            return
        }
        const index = session.currentIndex >= 0 && session.currentIndex < session.count
            ? session.currentIndex : preferredSession()
        errorText = ""
        showPassword = false
        signingIn = true
        sddm.login(user.text.trim(), password.text, index)
    }
    Component.onCompleted: Qt.callLater(function() {
        if (user.text.trim()) password.forceActiveFocus()
        else user.forceActiveFocus()
    })
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.signingIn = false
            root.errorText = "Sign-in failed. Check your credentials and try again."
            password.clear()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { password.clear() }
    }
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(420, root.width - 40)
        spacing: 14
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(root.now, "HH:mm")
            font.pixelSize: 74
            color: "#f0f5ff"
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 12
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            font.pixelSize: 17
            color: "#b7c5de"
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: form.implicitHeight + 44
            radius: 24
            color: "#171e2c"
            border.color: "#3a4964"
            ColumnLayout {
                id: form
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12
                Text { text: "Sign in"; color: "#f0f5ff"; font.pixelSize: 24 }
                TextField {
                    id: user
                    Layout.fillWidth: true
                    placeholderText: "Username"
                    text: userModel.lastUser || ""
                    readOnly: root.signingIn
                    Accessible.name: "Username"
                    onTextEdited: root.errorText = ""
                    onAccepted: {
                        if (password.text.length) root.login()
                        else password.forceActiveFocus()
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: password
                        Layout.fillWidth: true
                        placeholderText: "Password"
                        Accessible.name: "Password"
                        readOnly: root.signingIn
                        echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                        onTextEdited: root.errorText = ""
                        onAccepted: root.login()
                    }
                    Button {
                        text: root.showPassword ? "Hide" : "Show"
                        Accessible.name: root.showPassword ? "Hide password" : "Show password"
                        enabled: !root.signingIn
                        onClicked: root.showPassword = !root.showPassword
                    }
                }
                Text { text: "Desktop session"; color: "#b7c5de" }
                ComboBox {
                    id: session
                    Layout.fillWidth: true
                    model: sessionModel
                    textRole: "name"
                    Accessible.name: "Desktop session"
                    enabled: count > 0 && !root.signingIn
                    displayText: count > 0 ? currentText : "No sessions available"
                    currentIndex: count > 0 ? root.preferredSession() : -1
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.errorText
                    text: root.errorText
                    color: "#ffabb7"
                    wrapMode: Text.Wrap
                }
                Button {
                    Layout.fillWidth: true
                    text: root.signingIn ? "Signing in…" : "Sign in"
                    enabled: !root.signingIn
                    onClicked: root.login()
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Button { text: "Restart"; visible: sddm.canReboot; onClicked: sddm.reboot() }
            Button { text: "Shut down"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
        }
    }
}
