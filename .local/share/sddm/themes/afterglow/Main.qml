import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    width: 1920
    height: 1080

    // Material Design 3 palette tokens (configurable via theme.conf)
    readonly property color cSurface: config.surface || "#11151a"
    readonly property color cContainer: config.surfaceContainer || "#1c2027"
    readonly property color cContainerHigh: config.surfaceContainerHigh || "#272c35"
    readonly property color cPrimary: config.primary || "#b6c8e2"
    readonly property color cPrimaryContainer: config.primaryContainer || "#374c6c"
    readonly property color cOnPrimary: config.onPrimary || "#1b2636"
    readonly property color cOnSurface: config.onSurface || "#e1e5ea"
    readonly property color cOnSurfaceVariant: config.onSurfaceVariant || "#bbc3ce"
    readonly property color cOutlineVariant: config.outlineVariant || "#404854"
    readonly property color cError: config.error || "#ffb4ab"
    readonly property color cErrorContainer: config.errorContainer || "#93000a"

    FontLoader { id: headingFont; source: "fonts/Ndot55-Regular.otf" }
    FontLoader { id: bodyFont; source: "fonts/GoogleSansFlex.ttf" }
    readonly property string uiFont: bodyFont.status === FontLoader.Ready ? bodyFont.name : "sans-serif"
    readonly property string displayFont: headingFont.status === FontLoader.Ready ? headingFont.name : uiFont

    property bool isTestMode: Qt.application.arguments.indexOf("--test-mode") !== -1
    property string errorText: ""
    property bool signingIn: false
    property bool showPassword: false
    property int selectedSession: -1
    property date now: new Date()

    function initSession() {
        const count = sessionModel ? sessionModel.rowCount() : 0;
        if (count <= 0) {
            selectedSession = -1;
            return;
        }
        const last = sessionModel.lastIndex;
        selectedSession = (last >= 0 && last < count) ? last : 0;
    }

    function initUser() {
        if (userInput.text.trim()) return;
        if (userModel && userModel.lastUser) {
            userInput.text = userModel.lastUser;
            return;
        }
        if (userModel && userModel.rowCount() > 0) {
            const first = userModel.data(userModel.index(0, 0), Qt.UserRole + 1);
            if (first) userInput.text = String(first);
        }
    }

    function submitLogin() {
        if (signingIn) return;
        const username = userInput.text.trim();
        if (!username) {
            errorText = "ユーザー名を入力してください";
            shakeAnim.restart();
            userInput.forceActiveFocus();
            return;
        }
        const count = sessionModel ? sessionModel.rowCount() : 0;
        if (count <= 0) {
            errorText = "利用可能なデスクトップセッションがありません";
            shakeAnim.restart();
            return;
        }
        const idx = (selectedSession >= 0 && selectedSession < count) ? selectedSession : 0;
        errorText = "";
        showPassword = false;
        if (isTestMode) {
            if (!passwordInput.text) {
                errorText = "テストモード: パスワードを入力してください（実際の認証は本番SDDMで行われます）";
                shakeAnim.restart();
                passwordInput.forceActiveFocus();
                return;
            }
            signingIn = true;
            testSignInTimer.restart();
            return;
        }
        signingIn = true;
        sddm.login(username, passwordInput.text, idx);
    }

    Timer {
        id: testSignInTimer
        interval: 600
        onTriggered: {
            root.signingIn = false;
            root.errorText = "テストモードのため実際のログインは実行されません（Escで終了）";
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        initSession();
        initUser();
        Qt.callLater(function() {
            if (userInput.text.trim()) passwordInput.forceActiveFocus();
            else userInput.forceActiveFocus();
        });
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        enabled: Qt.application.arguments.indexOf("--test-mode") !== -1
        onActivated: Qt.quit()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.signingIn = false;
            root.errorText = "サインインに失敗しました。パスワードを確認してください。";
            passwordInput.text = "";
            shakeAnim.restart();
            passwordInput.forceActiveFocus();
        }
        function onLoginSucceeded() {
            passwordInput.text = "";
        }
    }

    // Background Surface + Optional Wallpaper + Subtle Ambient Glow
    Rectangle {
        anchors.fill: parent
        color: root.cSurface

        Image {
            anchors.fill: parent
            source: config.background || ""
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            opacity: 0.45
        }

        // Subtle Material You tonal ambient vignette
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(root.cPrimaryContainer, 0.32) }
                GradientStop { position: 0.55; color: Qt.alpha(root.cSurface, 0.85) }
                GradientStop { position: 1.0; color: root.cSurface }
            }
        }
    }

    // Main Centered Layout
    ColumnLayout {
        id: mainColumn
        anchors.centerIn: parent
        width: Math.max(300, Math.min(420, root.width - 48))
        spacing: 20

        // Clock Hero
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(root.now, "HH:mm")
                font.family: root.displayFont
                font.pixelSize: 82
                color: root.cOnSurface
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(root.now, "yyyy年 M月 d日 (dddd)")
                font.family: root.uiFont
                font.pixelSize: 15
                font.weight: Font.Medium
                color: root.cPrimary
            }
        }

        // M3 Extra-Large Sign-In Card
        Rectangle {
            id: loginCard
            Layout.fillWidth: true
            implicitHeight: formLayout.implicitHeight + 48
            radius: 28
            color: root.cContainer
            transform: Translate { id: cardShake; x: 0 }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: cardShake; property: "x"; to: -10; duration: 55; easing.type: Easing.OutCubic }
                NumberAnimation { target: cardShake; property: "x"; to: 10; duration: 70; easing.type: Easing.InOutCubic }
                NumberAnimation { target: cardShake; property: "x"; to: -6; duration: 60; easing.type: Easing.InOutCubic }
                NumberAnimation { target: cardShake; property: "x"; to: 6; duration: 55; easing.type: Easing.InOutCubic }
                NumberAnimation { target: cardShake; property: "x"; to: 0; duration: 50; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: formLayout
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                // User Picker Chips (if multiple users or quick-select)
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: userRepeater.count > 0

                    Repeater {
                        id: userRepeater
                        model: userModel
                        delegate: Rectangle {
                            id: userChip
                            required property string name
                            required property string realName
                            readonly property bool selected: userInput.text.trim() === name
                            height: 36
                            radius: 18
                            width: userChipRow.implicitWidth + 24
                            color: selected ? root.cPrimaryContainer : root.cContainerHigh
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: root.cOnSurface
                                opacity: uChipMouse.pressed ? 0.12 : uChipMouse.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }

                            Row {
                                id: userChipRow
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: userChip.selected ? root.cPrimary : root.cContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: (userChip.realName || userChip.name || "?").slice(0, 1).toUpperCase()
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: userChip.selected ? root.cOnPrimary : root.cOnSurface
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: userChip.realName || userChip.name
                                    font.family: root.uiFont
                                    font.pixelSize: 13
                                    font.weight: userChip.selected ? Font.DemiBold : Font.Medium
                                    color: userChip.selected ? root.cPrimary : root.cOnSurface
                                }
                            }

                            MouseArea {
                                id: uChipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.signingIn
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    userInput.text = userChip.name;
                                    root.errorText = "";
                                    passwordInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Username Field (M3 Outlined Input)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 50
                    radius: 16
                    color: root.cContainerHigh
                    border.width: userInput.activeFocus ? 2 : 1
                    border.color: userInput.activeFocus ? root.cPrimary : root.cOutlineVariant
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: userInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.cOnSurface
                        selectionColor: root.cPrimaryContainer
                        selectedTextColor: root.cOnSurface
                        font.family: root.uiFont
                        font.pixelSize: 14
                        readOnly: root.signingIn
                        clip: true
                        onTextEdited: root.errorText = ""
                        Keys.onReturnPressed: {
                            if (passwordInput.text.length > 0) root.submitLogin();
                            else passwordInput.forceActiveFocus();
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        KeyNavigation.tab: passwordInput
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: userInput.text.length === 0
                        text: "Username"
                        font.family: root.uiFont
                        font.pixelSize: 14
                        color: root.cOnSurfaceVariant
                    }
                }

                // Password Field (M3 Outlined Input + Show/Hide Pill)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 50
                    radius: 16
                    color: root.cContainerHigh
                    border.width: passwordInput.activeFocus ? 2 : 1
                    border.color: root.errorText ? root.cError
                                : passwordInput.activeFocus ? root.cPrimary : root.cOutlineVariant
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 72
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.cOnSurface
                        selectionColor: root.cPrimaryContainer
                        selectedTextColor: root.cOnSurface
                        font.family: root.uiFont
                        font.pixelSize: 14
                        echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                        readOnly: root.signingIn
                        clip: true
                        onTextEdited: root.errorText = ""
                        Keys.onReturnPressed: root.submitLogin()
                        Keys.onEnterPressed: root.submitLogin()
                        KeyNavigation.backtab: userInput
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length === 0
                        text: "Password"
                        font.family: root.uiFont
                        font.pixelSize: 14
                        color: root.cOnSurfaceVariant
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 54
                        height: 32
                        radius: 16
                        color: root.showPassword ? root.cPrimaryContainer : root.cContainer
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.showPassword ? "Hide" : "Show"
                            font.family: root.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.showPassword ? root.cPrimary : root.cOnSurfaceVariant
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.signingIn
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showPassword = !root.showPassword
                        }
                    }
                }

                // Desktop Session Selector (M3 Filter Chips — replaces buggy ComboBox)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: sessionRepeater.count > 0

                    Text {
                        text: "SESSION"
                        font.family: root.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        color: root.cOnSurfaceVariant
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            id: sessionRepeater
                            model: sessionModel
                            delegate: Rectangle {
                                id: sessChip
                                required property int index
                                required property string name
                                readonly property bool selected: root.selectedSession === index
                                height: 32
                                radius: 16
                                width: sessLabel.implicitWidth + 24
                                color: selected ? root.cPrimaryContainer : "transparent"
                                border.width: selected ? 0 : 1
                                border.color: root.cOutlineVariant
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: root.cOnSurface
                                    opacity: sessMouse.pressed ? 0.12 : sessMouse.containsMouse ? 0.08 : 0
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                }

                                Text {
                                    id: sessLabel
                                    anchors.centerIn: parent
                                    text: (sessChip.selected ? "✓ " : "") + sessChip.name
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                    font.weight: sessChip.selected ? Font.DemiBold : Font.Medium
                                    color: sessChip.selected ? root.cPrimary : root.cOnSurface
                                }

                                MouseArea {
                                    id: sessMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.signingIn
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedSession = sessChip.index;
                                        passwordInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // Error Banner (M3 Error Container)
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.errorText.length > 0
                    radius: 14
                    color: root.cErrorContainer
                    implicitHeight: errTxt.implicitHeight + 18

                    Text {
                        id: errTxt
                        anchors.fill: parent
                        anchors.margins: 9
                        text: root.errorText
                        font.family: root.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.cError
                        wrapMode: Text.Wrap
                    }
                }

                // M3 Filled Sign-In Pill Button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 24
                    color: root.signingIn ? root.cPrimaryContainer : root.cPrimary
                    scale: signMouse.pressed ? 0.98 : 1.0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: root.cOnPrimary
                        opacity: root.signingIn ? 0 : signMouse.pressed ? 0.14 : signMouse.containsMouse ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.signingIn ? "サインイン中…" : "サインイン"
                        font.family: root.uiFont
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: root.signingIn ? root.cPrimary : root.cOnPrimary
                    }

                    MouseArea {
                        id: signMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.signingIn
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitLogin()
                    }
                }
            }
        }

        // Bottom M3 Floating Power Pills
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Repeater {
                model: [
                    { label: "スリープ",       available: sddm.canSuspend,  destructive: false, act: "suspend" },
                    { label: "再起動",         available: sddm.canReboot,   destructive: false, act: "reboot" },
                    { label: "シャットダウン", available: sddm.canPowerOff, destructive: true,  act: "poweroff" }
                ]
                delegate: Rectangle {
                    id: pwrPill
                    required property var modelData
                    visible: modelData.available
                    height: 38
                    radius: 19
                    width: pwrLabel.implicitWidth + 32
                    color: modelData.destructive ? root.cErrorContainer : root.cContainer
                    scale: pwrMouse.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: root.cOnSurface
                        opacity: pwrMouse.pressed ? 0.14 : pwrMouse.containsMouse ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    Text {
                        id: pwrLabel
                        anchors.centerIn: parent
                        text: pwrPill.modelData.label
                        font.family: root.uiFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: pwrPill.modelData.destructive ? root.cError : root.cOnSurface
                    }

                    MouseArea {
                        id: pwrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.signingIn
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pwrPill.modelData.act === "suspend") sddm.suspend();
                            else if (pwrPill.modelData.act === "reboot") sddm.reboot();
                            else if (pwrPill.modelData.act === "poweroff") sddm.powerOff();
                        }
                    }
                }
            }
        }
    }
}
