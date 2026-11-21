import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    property var shellState
    property var launcher
    property bool opened: false
    property bool closing: false
    property bool alertsOnly: false
    readonly property bool notificationsOpen: alertsOnly
    property string detailPage: ""

    // Mini system-control states (full management lives in System Settings)
    property int brightness: -1
    property int pendingBrightness: -1
    property bool brightnessUserChanged: false
    property string bluetoothStatus: ""
    property var connectedBluetooth: []
    property string currentSsid: ""

    property bool capturePending: false
    property bool captureWithoutEditor: false
    property bool captureText: false
    property bool translateText: false
    property bool imageSearch: false

    readonly property var cfg: root.shellState ? root.shellState.settingsController : null
    readonly property var activePlayer: Mpris.players.values.find(p => p.isPlaying)
        || Mpris.players.values[0] || null
    readonly property bool bluetoothPowered: /Powered:\s+yes/.test(bluetoothStatus)
    readonly property string networkLabel: root.shellState ? (root.shellState.networkLabel || "OFF") : "OFF"
    readonly property bool networkConnected: networkLabel !== "OFF" && networkLabel !== ""

    readonly property string pageSubtitle: {
        if (notificationsOpen) return "Recent activity and alerts";
        switch (detailPage) {
        case "Colors": return "Material You dynamic theme & presets";
        case "Wallpapers": return "Desktop backgrounds across displays";
        case "Top Bar": return "Dynamic Island, AI Usage & Earthquake";
        case "Bar & Weather": return "Rail toggles, clock & weather location";
        case "Capture": return "Screenshot, OCR & visual search";
        case "Windows": return "Workspaces & active windows";
        case "Daily Tools": return "Focus timer, stopwatch & notes";
        case "Clipboard": return "Recent copied text snippets";
        default: return "Dotfiles hub & quick controls";
        }
    }

    function requestBrightness(percent) {
        const clamped = Math.max(1, Math.min(100, Math.round(percent)));
        brightness = clamped;
        pendingBrightness = clamped;
        brightnessUserChanged = true;
        brightnessDebounce.restart();
    }

    function groupNotifications(items) {
        const groups = new Map();
        for (const item of items) {
            if (!groups.has(item.app)) groups.set(item.app, []);
            groups.get(item.app).push(item);
        }
        const result = [];
        groups.forEach(group => group.forEach(item => result.push(item)));
        return result;
    }

    function triggerCapture(withoutEditor, withText, translate, imgSearch) {
        if (capturePending) return;
        capturePending = true;
        captureWithoutEditor = withoutEditor;
        captureText = withText;
        translateText = translate;
        imageSearch = imgSearch;
        closeTools();
        captureDelay.restart();
    }

    function openSystemPage(pageIndex) {
        closeTools();
        if (root.shellState) root.shellState.openSettingsPage(root.screen, pageIndex);
    }

    VolumeOsd {
        screen: root.screen
        label: "Brightness"
        percent: Math.max(0, root.brightness)
        muted: false
        available: root.brightness >= 0 && root.brightnessUserChanged
    }
    Process {
        id: readBrightness
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/monitor-brightness.py", root.screen?.name ?? "", "read"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.trim().match(/^(\d+)$/);
                root.brightness = match ? Number(match[1]) : -1;
            }
        }
        onExited: code => { if (code !== 0) root.brightness = -1; }
    }
    Timer {
        id: brightnessDebounce
        interval: 180
        onTriggered: {
            if (root.pendingBrightness < 0) return;
            setBrightness.targetValue = String(root.pendingBrightness);
            setBrightness.running = true;
        }
    }
    Process {
        id: setBrightness
        property string targetValue: ""
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/monitor-brightness.py", root.screen?.name ?? "", "set", targetValue]
        onExited: readBrightness.running = true
    }
    Process {
        id: bluetooth
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector { onStreamFinished: root.bluetoothStatus = text.trim() }
    }
    Process {
        id: connectedDevices
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: root.connectedBluetooth = text.split("\n").map(line => {
                const m = line.match(/^Device ([0-9a-f:]{17}) (.+)$/i);
                return m ? { address: m[1], name: m[2] } : null;
            }).filter(Boolean)
        }
    }
    Process {
        id: activeWifi
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "device", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("yes:"));
                root.currentSsid = line ? line.slice(4).trim() : "";
            }
        }
    }

    Timer {
        id: cityDebounce
        interval: 320
        onTriggered: if (root.cfg) root.cfg.searchCity(weatherCityInput.text)
    }

    onDetailPageChanged: {
        if (opened && !notificationsOpen) detailMotion.restart();
        if (detailPage === "Bar & Weather" && root.cfg) {
            weatherCityInput.text = root.cfg.weatherCity;
            root.cfg.citySuggestions = [];
        }
    }

    Timer {
        id: captureDelay
        interval: 270
        onTriggered: {
            root.capturePending = false;
            const path = root.captureWithoutEditor
                ? "/.config/quickshell/main/capture-region.py" : "/.config/hypr/flameshot-screen.py";
            const args = ["python3", Quickshell.env("HOME") + path];
            if (root.captureText) args.push(root.translateText ? "--translate" : "--ocr");
            if (root.imageSearch) args.push("--image-search");
            root.imageSearch = false;
            Quickshell.execDetached(args);
        }
    }

    onOpenedChanged: if (opened) {
        detailPage = "";
        if (alertsOnly) {
            if (shellState) shellState.unreadNotifications = 0;
        } else {
            brightnessUserChanged = false;
            if (!readBrightness.running) readBrightness.running = true;
            if (!bluetooth.running) bluetooth.running = true;
            if (!connectedDevices.running) connectedDevices.running = true;
            if (networkLabel === "WIFI" && !activeWifi.running) activeWifi.running = true;
        }
    }

    function toggle() {
        if (opened) closeTools();
        else openTools();
    }

    function openTools() {
        closeTimer.stop();
        closing = false;
        opened = true;
    }

    function closeTools() {
        if (!opened) return;
        opened = false;
        closing = true;
        closeTimer.restart();
    }

    visible: opened || closing
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: opened && (detailPage === "Daily Tools" || detailPage === "Clipboard" || detailPage === "Bar & Weather") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    mask: root.opened ? (root.alertsOnly ? null : panelInput) : emptyInput
    Region { id: panelInput; item: reveal }
    Region { id: emptyInput; width: 0; height: 0 }

    MouseArea {
        anchors.fill: parent
        enabled: root.alertsOnly && root.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeTools()
    }
    IpcHandler {
        target: (root.alertsOnly ? "alerts_" : "quickTools_") + (root.screen?.name ?? "unknown")
        function toggle(): void { root.toggle(); }
    }

    Timer {
        id: closeTimer
        interval: Theme.motion.exit + 20
        onTriggered: root.closing = false
    }

    Item {
        id: reveal
        x: root.alertsOnly ? parent.width - width : Theme.shape.railWidth
        anchors.top: parent.top
        anchors.topMargin: root.alertsOnly ? Theme.shape.islandReservation : 0
        height: root.alertsOnly ? Math.min(560, parent.height - y) : parent.height
        readonly property real panelWidth: Math.min(392, Math.max(1, parent.width - Theme.shape.railWidth))
        width: root.opened ? panelWidth : 0
        clip: true
        Behavior on width {
            NumberAnimation {
                duration: root.opened ? Theme.motion.standard : Theme.motion.exit
                easing.type: root.opened ? Easing.OutCubic : Easing.InOutCubic
            }
        }
    }

    Rectangle {
        id: panel
        parent: reveal
        x: root.alertsOnly ? 0 : parent.width - width
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: reveal.panelWidth
        radius: Theme.shape.dialogRadius
        topLeftRadius: root.alertsOnly ? radius : 0
        bottomLeftRadius: root.alertsOnly ? radius : 0
        topRightRadius: root.alertsOnly ? 0 : radius
        bottomRightRadius: root.alertsOnly ? 0 : radius
        color: LivePalette.color.surface
        clip: true

        MouseArea {
            anchors.fill: parent
            enabled: root.alertsOnly
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        Dialog {
            id: translationConsent
            anchors.centerIn: parent
            width: parent.width - 28
            height: 196
            modal: true
            palette.window: LivePalette.color.surfaceContainer
            palette.button: LivePalette.color.surfaceContainerHigh
            palette.windowText: LivePalette.color.onSurface
            palette.buttonText: LivePalette.color.onSurface
            title: "Translate Screen Text"
            standardButtons: Dialog.Ok | Dialog.Cancel
            contentItem: Label {
                text: "The text recognized in the area you select will be sent to Google Translate. The screenshot is not uploaded."
                wrapMode: Text.Wrap
            }
            onAccepted: root.triggerCapture(true, true, true, false)
        }

        Control {
            anchors.fill: parent
            padding: 18
            font.family: toolsFont.status === FontLoader.Ready ? toolsFont.name : Qt.application.font.family
            palette.window: LivePalette.color.surfaceContainer
            palette.base: LivePalette.color.surface
            palette.button: LivePalette.color.surfaceContainerHigh
            palette.windowText: LivePalette.color.onSurface
            palette.buttonText: LivePalette.color.onSurface
            palette.text: LivePalette.color.onSurface
            palette.highlight: LivePalette.color.primaryContainer
            palette.highlightedText: LivePalette.color.onSurface
            palette.placeholderText: LivePalette.color.onSurfaceVariant

            FontLoader { id: toolsFont; source: "fonts/GoogleSansFlex.ttf" }

            Keys.onEscapePressed: {
                if (root.detailPage) root.detailPage = "";
                else root.closeTools();
            }

            contentItem: ColumnLayout {
                spacing: 14

                // ================= HEADER =================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    HeaderIconButton {
                        visible: !!root.detailPage
                        iconName: "go-previous-symbolic"
                        label: "Back"
                        onClicked: root.detailPage = ""
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.detailPage || (root.notificationsOpen ? "Notifications" : "Quick Tools")
                            font.family: "Ndot 55"
                            color: LivePalette.color.onSurface
                            font.pixelSize: 20
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.pageSubtitle
                            font.family: toolsFont.name || Qt.application.font.family
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    HeaderIconButton {
                        iconName: "window-close-symbolic"
                        label: "Close quick tools"
                        onClicked: root.closeTools()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.alpha(LivePalette.color.outlineVariant, 0.45)
                }

                // ================= CONTENT =================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Item {
                        id: pageContent
                        anchors.fill: parent
                        transform: Translate { id: pageOffset }

                        ParallelAnimation {
                            id: detailMotion
                            NumberAnimation {
                                target: pageContent; property: "opacity"
                                from: 0.4; to: 1
                                duration: Theme.motion.fast; easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: pageOffset; property: "x"
                                from: root.detailPage ? 16 : -10; to: 0
                                duration: Theme.motion.standard; easing.type: Easing.OutQuint
                            }
                        }

                        // ================= VIEW: QUICK TOOLS HOME =================
                        ScrollView {
                            anchors.fill: parent
                            opacity: !root.notificationsOpen && !root.detailPage ? 1 : 0
                            visible: opacity > 0
                            enabled: !root.notificationsOpen && !root.detailPage
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            ColumnLayout {
                                width: parent.width
                                spacing: 14

                                // Mini System Controls (2x2)
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 8
                                    columnSpacing: 8

                                    QuickTile {
                                        Layout.fillWidth: true
                                        iconName: root.networkLabel === "ETH" ? "network-wired-symbolic" : "network-wireless-symbolic"
                                        title: "Network"
                                        subtitle: root.networkLabel === "WIFI" ? (root.currentSsid || "Wi-Fi active")
                                                : root.networkLabel === "ETH" ? "Ethernet" : "Disconnected"
                                        active: root.networkConnected
                                        onClicked: root.openSystemPage(0)
                                    }

                                    QuickTile {
                                        Layout.fillWidth: true
                                        iconName: "bluetooth-symbolic"
                                        title: "Bluetooth"
                                        subtitle: !root.bluetoothStatus ? "Checking…"
                                                : !root.bluetoothPowered ? "Off"
                                                : root.connectedBluetooth.length === 1 ? root.connectedBluetooth[0].name
                                                : root.connectedBluetooth.length > 1 ? root.connectedBluetooth.length + " connected"
                                                : "Active"
                                        active: root.bluetoothPowered
                                        onClicked: root.openSystemPage(1)
                                    }

                                    QuickTile {
                                        Layout.fillWidth: true
                                        iconName: (root.shellState?.doNotDisturb ?? false)
                                            ? "notifications-disabled-symbolic"
                                            : "preferences-system-notifications-symbolic"
                                        title: "Silent"
                                        subtitle: (root.shellState?.doNotDisturb ?? false) ? "Do Not Disturb" : "Alerts on"
                                        active: root.shellState?.doNotDisturb ?? false
                                        hasChevron: false
                                        onClicked: if (root.shellState) root.shellState.doNotDisturb = !root.shellState.doNotDisturb
                                    }

                                    QuickTile {
                                        Layout.fillWidth: true
                                        iconName: "camera-photo-symbolic"
                                        title: "Capture"
                                        subtitle: "Screen & OCR"
                                        active: false
                                        onClicked: root.detailPage = "Capture"
                                    }
                                }

                                // Now Playing Card
                                Rectangle {
                                    visible: !!root.activePlayer
                                    Layout.fillWidth: true
                                    radius: 22
                                    color: root.activePlayer?.isPlaying
                                        ? LivePalette.color.primaryContainer
                                        : LivePalette.color.surfaceContainer
                                    implicitHeight: 74
                                    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 46
                                            Layout.preferredHeight: 46
                                            radius: 14
                                            color: LivePalette.color.surfaceContainerHigh
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: root.activePlayer?.trackArtUrl ?? ""
                                                fillMode: Image.PreserveAspectCrop
                                                visible: status === Image.Ready
                                            }
                                            SymbolIcon {
                                                anchors.centerIn: parent
                                                visible: !(root.activePlayer?.trackArtUrl)
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                iconName: "audio-x-generic-symbolic"
                                                tint: LivePalette.color.primary
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.activePlayer?.trackTitle || root.activePlayer?.identity || "Media"
                                                textFormat: Text.PlainText
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                color: LivePalette.color.onSurface
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.activePlayer?.trackArtist || (root.activePlayer?.isPlaying ? "Playing" : "Paused")
                                                textFormat: Text.PlainText
                                                font.pixelSize: 11
                                                color: LivePalette.color.onSurfaceVariant
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            spacing: 4
                                            HeaderIconButton {
                                                implicitWidth: 30; implicitHeight: 30; radius: 15
                                                iconName: "media-skip-backward-symbolic"
                                                label: "Previous track"
                                                onClicked: if (root.activePlayer) root.activePlayer.previous()
                                            }
                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: playMouse.pressed ? Qt.darker(LivePalette.color.primary, 1.12)
                                                     : playMouse.containsMouse ? Qt.lighter(LivePalette.color.primary, 1.08)
                                                     : LivePalette.color.primary
                                                scale: playMouse.pressed ? 0.94 : 1.0
                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                                SymbolIcon {
                                                    anchors.centerIn: parent
                                                    implicitWidth: 16; implicitHeight: 16
                                                    iconName: root.activePlayer?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                                                    tint: LivePalette.color.onPrimary
                                                }
                                                MouseArea {
                                                    id: playMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
                                                }
                                            }
                                            HeaderIconButton {
                                                implicitWidth: 30; implicitHeight: 30; radius: 15
                                                iconName: "media-skip-forward-symbolic"
                                                label: "Next track"
                                                onClicked: if (root.activePlayer) root.activePlayer.next()
                                            }
                                        }
                                    }
                                }

                                // Mini Audio & Display Sliders
                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: 22
                                    color: LivePalette.color.surfaceContainer
                                    implicitHeight: controlsCol.implicitHeight + 28

                                    ColumnLayout {
                                        id: controlsCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 14

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                                    color: muteMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                                                    SymbolIcon {
                                                        anchors.centerIn: parent
                                                        implicitWidth: 16; implicitHeight: 16
                                                        iconName: root.shellState?.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                                                        tint: root.shellState?.volumeMuted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                                                    }
                                                    MouseArea {
                                                        id: muteMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                                    }
                                                }

                                                Text { text: "Volume"; color: LivePalette.color.onSurface; font.pixelSize: 13; font.weight: Font.Medium }
                                                Item { Layout.fillWidth: true }

                                                Rectangle {
                                                    radius: 8; color: LivePalette.color.surfaceContainerHigh
                                                    implicitWidth: volVal.implicitWidth + 12; implicitHeight: 22
                                                    Text {
                                                        id: volVal
                                                        anchors.centerIn: parent
                                                        text: root.shellState?.volumeMuted ? "Muted" : (root.shellState?.volumePercent ?? 0) + "%"
                                                        color: root.shellState?.volumeMuted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                                                        font.pixelSize: 11; font.weight: Font.DemiBold
                                                    }
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                implicitHeight: 28
                                                BarSlider {
                                                    anchors.fill: parent
                                                    from: 0; to: 100
                                                    value: root.shellState?.volumePercent ?? 0
                                                    enabled: root.shellState?.volumeAvailable ?? false
                                                    onMoved: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)])
                                                }
                                                WheelHandler {
                                                    enabled: root.shellState?.volumeAvailable ?? false
                                                    onWheel: event => {
                                                        const delta = event.angleDelta.y > 0 ? "3%+" : "3%-";
                                                        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", delta]);
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(LivePalette.color.outlineVariant, 0.4) }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                                    color: brightMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                                                    SymbolIcon {
                                                        anchors.centerIn: parent
                                                        implicitWidth: 16; implicitHeight: 16
                                                        iconName: "display-brightness-symbolic"
                                                        tint: root.brightness >= 0 ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                                    }
                                                    MouseArea {
                                                        id: brightMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.openSystemPage(2)
                                                    }
                                                }

                                                Text { text: "Brightness"; color: LivePalette.color.onSurface; font.pixelSize: 13; font.weight: Font.Medium }
                                                Item { Layout.fillWidth: true }

                                                Rectangle {
                                                    radius: 8; color: LivePalette.color.surfaceContainerHigh
                                                    implicitWidth: brightVal.implicitWidth + 12; implicitHeight: 22
                                                    Text {
                                                        id: brightVal
                                                        anchors.centerIn: parent
                                                        text: readBrightness.running && root.brightness < 0 ? "…"
                                                            : root.brightness >= 0 ? root.brightness + "%" : "N/A"
                                                        color: root.brightness >= 0 ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                                        font.pixelSize: 11; font.weight: Font.DemiBold
                                                    }
                                                }
                                            }

                                            Item {
                                                visible: root.brightness >= 0
                                                Layout.fillWidth: true
                                                implicitHeight: 28
                                                BarSlider {
                                                    anchors.fill: parent
                                                    from: 1; to: 100
                                                    value: Math.max(1, root.brightness)
                                                    onMoved: root.requestBrightness(value)
                                                }
                                                WheelHandler {
                                                    onWheel: event => {
                                                        const step = event.angleDelta.y > 0 ? 5 : -5;
                                                        root.requestBrightness(root.brightness + step);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // DOTFILES & SHELL Section
                                Text {
                                    Layout.fillWidth: true
                                    text: "DOTFILES & SHELL"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 8
                                    columnSpacing: 8

                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "applications-graphics-symbolic"
                                        title: "Colors"
                                        onClicked: root.detailPage = "Colors"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "image-x-generic-symbolic"
                                        title: "Wallpapers"
                                        onClicked: root.detailPage = "Wallpapers"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "view-more-symbolic"
                                        title: "Top Bar"
                                        onClicked: root.detailPage = "Top Bar"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "preferences-desktop-theme-symbolic"
                                        title: "Bar & Weather"
                                        onClicked: root.detailPage = "Bar & Weather"
                                    }
                                }

                                // TOOLS & SYSTEM Section
                                Text {
                                    Layout.fillWidth: true
                                    text: "TOOLS"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 8
                                    columnSpacing: 8

                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "view-grid-symbolic"
                                        title: "Windows"
                                        onClicked: root.detailPage = "Windows"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "preferences-system-time-symbolic"
                                        title: "Daily Tools"
                                        onClicked: root.detailPage = "Daily Tools"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "edit-paste-symbolic"
                                        title: "Clipboard"
                                        onClicked: root.detailPage = "Clipboard"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "preferences-system-symbolic"
                                        title: "System Settings"
                                        onClicked: root.openSystemPage(0)
                                    }
                                }

                                Item { implicitHeight: 6 }
                            }
                        }

                        // ================= DETAIL: COLORS (DOTFILES) =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Colors"
                            spacing: 12

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 10
                                columnSpacing: 10

                                Repeater {
                                    model: [
                                        { label: "Wallpaper Auto", mode: "auto", color: "#b8a6d9", desc: "Dynamic from image" },
                                        { label: "Sakura Pink",    mode: "pink", color: "#ffb0ca", desc: "Gentle pink accent" },
                                        { label: "Sky Blue",       mode: "blue", color: "#a9c7ff", desc: "Cool serene blue" },
                                        { label: "Forest Green",   mode: "green", color: "#a6d0a0", desc: "Natural soft green" }
                                    ]
                                    delegate: Rectangle {
                                        id: palTile
                                        required property var modelData
                                        readonly property bool selected: root.cfg && root.cfg.paletteMode === modelData.mode
                                        Layout.fillWidth: true
                                        implicitHeight: 112
                                        radius: 22
                                        color: selected ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
                                        scale: pMouse.pressed ? 0.97 : 1.0
                                        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                        Rectangle {
                                            anchors.fill: parent; radius: parent.radius; color: LivePalette.color.onSurface
                                            opacity: pMouse.pressed ? 0.12 : pMouse.containsMouse ? 0.08 : 0
                                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 6

                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: palTile.modelData.color
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: palTile.selected
                                                    text: "✓"
                                                    font.pixelSize: 15
                                                    font.weight: Font.Bold
                                                    color: "#1b2636"
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: palTile.modelData.label
                                                font.pixelSize: 13
                                                font.weight: palTile.selected ? Font.DemiBold : Font.Medium
                                                color: LivePalette.color.onSurface
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: palTile.modelData.desc
                                                font.pixelSize: 11
                                                color: LivePalette.color.onSurfaceVariant
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            id: pMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (root.cfg) root.cfg.applyPalette(palTile.modelData.mode)
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: 11
                                color: root.cfg && root.cfg.paletteFailed ? LivePalette.color.error : LivePalette.color.onSurfaceVariant
                                text: root.cfg && root.cfg.paletteFailed
                                    ? "Failed to generate palette. Reverting."
                                    : "Automatically syncs Quickshell, Hyprland, Kitty, Fcitx5, Qt6, and GTK3/4."
                            }
                            Item { Layout.fillHeight: true }
                        }

                        // ================= DETAIL: WALLPAPERS (DOTFILES) =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Wallpapers"
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                SettingsActionButton {
                                    Layout.fillWidth: true
                                    primary: true
                                    iconName: "document-open-symbolic"
                                    text: root.cfg && root.cfg.pickingFile ? "Opening Picker…" : "Choose File…"
                                    enabled: !(root.cfg && root.cfg.pickingFile)
                                    onClicked: if (root.cfg) root.cfg.chooseFile("wallpaper")
                                }
                                SettingsActionButton {
                                    visible: !!(root.shellState && root.shellState.wallpaperPath)
                                    iconName: "edit-delete-symbolic"
                                    text: "Clear"
                                    onClicked: if (root.shellState) root.shellState.setWallpaper("")
                                }
                            }

                            WallpaperBrowser {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                selected: root.shellState?.wallpaperPath ?? ""
                                onChosen: path => { if (root.shellState) root.shellState.setWallpaper(path); }
                            }
                        }

                        // ================= DETAIL: TOP BAR (DOTFILES) =================
                        ScrollView {
                            anchors.fill: parent
                            visible: root.detailPage === "Top Bar"
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width
                                spacing: 14

                                Text {
                                    text: "LEFT ISLAND WIDGET"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { mode: "music",      title: "Music & Window",     sub: "Now playing or active title", icon: "audio-x-generic-symbolic" },
                                            { mode: "earthquake", title: "Earthquake Monitor", sub: "Latest JMA seismic report",   icon: "dialog-warning-symbolic" },
                                            { mode: "none",       title: "Hidden",             sub: "Keep left slot empty",        icon: "view-conceal-symbolic" },
                                            { mode: "custom",     title: "Custom QML",         sub: "External island component",   icon: "applications-engineering-symbolic" }
                                        ]
                                        delegate: ToolCard {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            iconName: modelData.icon
                                            title: modelData.title
                                            subtitle: modelData.sub
                                            active: root.cfg && root.cfg.islandDisplay === modelData.mode
                                            badge: active ? "Active" : ""
                                            onClicked: {
                                                if (!root.cfg) return;
                                                if (modelData.mode === "custom" && !root.cfg.islandPlugin) {
                                                    root.cfg.chooseFile("plugin");
                                                    return;
                                                }
                                                root.cfg.setIslandDisplay(modelData.mode);
                                            }
                                        }
                                    }

                                    SettingsActionButton {
                                        visible: !!(root.cfg && root.cfg.islandDisplay === "custom")
                                        Layout.fillWidth: true
                                        iconName: "document-open-symbolic"
                                        text: root.cfg && root.cfg.islandPlugin ? "Change Custom QML…" : "Choose Custom QML…"
                                        onClicked: if (root.cfg) root.cfg.chooseFile("plugin")
                                    }
                                }

                                Text {
                                    text: "AI USAGE INDICATOR"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "Auto",         value: "auto" },
                                            { label: "Codex",        value: "codex" },
                                            { label: "Antigravity",  value: "antigravity" },
                                            { label: "Opencode",     value: "opencode" },
                                            { label: "Claude",       value: "claude" },
                                            { label: "Mistral",      value: "mistral" },
                                            { label: "Command Code", value: "command-code" },
                                            { label: "Gemini",       value: "gemini" }
                                        ]
                                        delegate: Rectangle {
                                            id: aiChip
                                            required property var modelData
                                            readonly property bool selected: root.cfg && root.cfg.quotaProvider === modelData.value
                                            height: 32; radius: 16; width: aiChipRow.implicitWidth + 20
                                            color: selected ? LivePalette.color.primaryContainer : "transparent"
                                            border.width: selected ? 0 : 1; border.color: LivePalette.color.outlineVariant
                                            Row {
                                                id: aiChipRow; anchors.centerIn: parent; spacing: 6
                                                ProviderIcon { width: 13; height: 13; anchors.verticalCenter: parent.verticalCenter; providerId: aiChip.modelData.value; tint: aiChip.selected ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant }
                                                Text { anchors.verticalCenter: parent.verticalCenter; text: aiChip.modelData.label; font.pixelSize: 12; font.weight: aiChip.selected ? Font.DemiBold : Font.Medium; color: aiChip.selected ? LivePalette.color.primary : LivePalette.color.onSurface }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.cfg) root.cfg.setQuotaProvider(aiChip.modelData.value) }
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "30 s", value: 30 }, { label: "1 min", value: 60 },
                                            { label: "5 min", value: 300 }, { label: "15 min", value: 900 }
                                        ]
                                        delegate: Rectangle {
                                            id: qiChip
                                            required property var modelData
                                            readonly property bool selected: root.cfg && root.cfg.quotaInterval === modelData.value
                                            height: 30; radius: 15; width: qiTxt.implicitWidth + 22
                                            color: selected ? LivePalette.color.primaryContainer : "transparent"
                                            border.width: selected ? 0 : 1; border.color: LivePalette.color.outlineVariant
                                            Text { id: qiTxt; anchors.centerIn: parent; text: qiChip.modelData.label; font.pixelSize: 11; font.weight: qiChip.selected ? Font.DemiBold : Font.Medium; color: qiChip.selected ? LivePalette.color.primary : LivePalette.color.onSurface }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.cfg) root.cfg.setQuotaInterval(qiChip.modelData.value) }
                                        }
                                    }
                                }

                                Text {
                                    text: "EARTHQUAKE UPDATES"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "Realtime (WS)", value: 0 },
                                            { label: "30 s", value: 30 },
                                            { label: "1 min", value: 60 },
                                            { label: "5 min", value: 300 }
                                        ]
                                        delegate: Rectangle {
                                            id: eqChip
                                            required property var modelData
                                            readonly property bool selected: root.cfg && root.cfg.earthquakeInterval === modelData.value
                                            height: 32; radius: 16; width: eqTxt.implicitWidth + 22
                                            color: selected ? LivePalette.color.primaryContainer : "transparent"
                                            border.width: selected ? 0 : 1; border.color: LivePalette.color.outlineVariant
                                            Text { id: eqTxt; anchors.centerIn: parent; text: (eqChip.selected ? "✓ " : "") + eqChip.modelData.label; font.pixelSize: 12; font.weight: eqChip.selected ? Font.DemiBold : Font.Medium; color: eqChip.selected ? LivePalette.color.primary : LivePalette.color.onSurface }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.cfg) root.cfg.setEarthquakeInterval(eqChip.modelData.value) }
                                        }
                                    }
                                }

                                Item { implicitHeight: 8 }
                            }
                        }

                        // ================= DETAIL: BAR & WEATHER (DOTFILES) =================
                        ScrollView {
                            anchors.fill: parent
                            visible: root.detailPage === "Bar & Weather"
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width
                                spacing: 10

                                ToggleRow {
                                    Layout.fillWidth: true
                                    iconName: "view-grid-symbolic"
                                    title: "Show Taskbar"
                                    subtitle: "Pinned & running apps on the left rail"
                                    checked: root.shellState?.showTaskbar ?? true
                                    onToggled: if (root.shellState) root.shellState.showTaskbar = !root.shellState.showTaskbar
                                }
                                ToggleRow {
                                    Layout.fillWidth: true
                                    iconName: "preferences-system-symbolic"
                                    title: "Show System Tray"
                                    subtitle: "Background app icons in the rail"
                                    checked: root.shellState?.showTray ?? true
                                    onToggled: if (root.shellState) root.shellState.showTray = !root.shellState.showTray
                                }
                                ToggleRow {
                                    Layout.fillWidth: true
                                    iconName: "preferences-system-time-symbolic"
                                    title: "Desktop Clock"
                                    subtitle: "Show large clock on wallpaper"
                                    checked: root.shellState?.desktopClock ?? false
                                    onToggled: if (root.shellState) root.shellState.setDesktopClock(!root.shellState.desktopClock)
                                }

                                Text {
                                    Layout.topMargin: 6
                                    text: "WEATHER LOCATION"
                                    font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    TextField {
                                        id: weatherCityInput
                                        Layout.fillWidth: true
                                        implicitHeight: 42
                                        placeholderText: "City (e.g. Nagoya, Tokyo)…"
                                        leftPadding: 14
                                        color: LivePalette.color.onSurface
                                        placeholderTextColor: LivePalette.color.onSurfaceVariant
                                        background: Rectangle {
                                            radius: 14
                                            color: LivePalette.color.surfaceContainer
                                            border.width: weatherCityInput.activeFocus ? 2 : 1
                                            border.color: weatherCityInput.activeFocus ? LivePalette.color.primary : LivePalette.color.outlineVariant
                                        }
                                        onTextEdited: cityDebounce.restart()
                                        onAccepted: {
                                            if (root.cfg) {
                                                root.cfg.setWeatherCity(text.trim());
                                                root.cfg.citySuggestions = [];
                                            }
                                        }
                                    }
                                    SettingsActionButton {
                                        primary: true
                                        text: "Save"
                                        enabled: !!root.cfg && weatherCityInput.text.trim() !== root.cfg.weatherCity
                                        onClicked: {
                                            root.cfg.setWeatherCity(weatherCityInput.text.trim());
                                            root.cfg.citySuggestions = [];
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: !!(root.cfg && root.cfg.citySuggestions.length > 0)
                                    Repeater {
                                        model: root.cfg ? root.cfg.citySuggestions : []
                                        delegate: ToolCard {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            iconName: "mark-location-symbolic"
                                            title: modelData.name
                                            subtitle: (modelData.admin ? modelData.admin + ", " : "") + modelData.country
                                            onClicked: {
                                                weatherCityInput.text = modelData.name;
                                                root.cfg.setWeatherCity(modelData.name);
                                                root.cfg.citySuggestions = [];
                                            }
                                        }
                                    }
                                }

                                Item { implicitHeight: 8 }
                            }
                        }

                        // ================= DETAIL: WINDOWS =================
                        ColumnLayout {
                            id: windowList
                            anchors.fill: parent
                            visible: root.detailPage === "Windows"
                            spacing: 12

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: windowList.visible ? Hyprland.workspaces.values.filter(ws => ws.id > 0) : []
                                    delegate: SettingsActionButton {
                                        required property var modelData
                                        implicitHeight: 32
                                        horizontalPadding: 14
                                        text: "WS " + modelData.id
                                        primary: modelData.focused
                                        onClicked: {
                                            Hyprland.dispatch(Hyprland.usingLua
                                                ? "hl.dsp.focus({ workspace = " + modelData.id + " })"
                                                : "workspace " + modelData.id);
                                            root.closeTools();
                                        }
                                    }
                                }
                            }

                            GridView {
                                id: windowGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                cellWidth: width / 2
                                cellHeight: 124
                                model: windowList.visible ? Hyprland.toplevels.values : []
                                delegate: Item {
                                    id: windowTile
                                    required property var modelData
                                    width: windowGrid.cellWidth
                                    height: windowGrid.cellHeight

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: 16
                                        color: LivePalette.color.surfaceContainer
                                        clip: true

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 0
                                            ScreencopyView {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                captureSource: windowTile.modelData.wayland
                                                live: false
                                                paintCursor: false
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 28
                                                color: LivePalette.color.surfaceContainerHigh
                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: windowTile.modelData.title || "Window"
                                                    textFormat: Text.PlainText
                                                    font.pixelSize: 11
                                                    color: LivePalette.color.onSurface
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const raw = windowTile.modelData.address;
                                                const address = raw.startsWith("0x") ? raw : "0x" + raw;
                                                Hyprland.dispatch(Hyprland.usingLua
                                                    ? "hl.dsp.focus({ window = 'address:" + address + "' })"
                                                    : "focuswindow address:" + address);
                                                root.closeTools();
                                            }
                                        }
                                    }
                                }
                                ScrollBar.vertical: ScrollBar {}
                            }
                        }

                        // ================= DETAIL: CAPTURE =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Capture"
                            spacing: 8

                            ToolCard { Layout.fillWidth: true; iconName: "camera-photo-symbolic"; title: "Screenshot (Editor)"; subtitle: "Capture & annotate with Flameshot"; enabled: !root.capturePending; onClicked: root.triggerCapture(false, false, false, false) }
                            ToolCard { Layout.fillWidth: true; iconName: "document-save-symbolic"; title: "Save Region"; subtitle: "Select an area and save immediately"; enabled: !root.capturePending; onClicked: root.triggerCapture(true, false, false, false) }
                            ToolCard { Layout.fillWidth: true; iconName: "edit-find-symbolic"; title: "Read Screen Text (OCR)"; subtitle: "Extract text from a selected area"; enabled: !root.capturePending; onClicked: root.triggerCapture(true, true, false, false) }
                            ToolCard { Layout.fillWidth: true; iconName: "preferences-desktop-locale-symbolic"; title: "Translate Screen Text"; subtitle: "Recognize text & open Google Translate"; enabled: !root.capturePending; onClicked: translationConsent.open() }
                            ToolCard { Layout.fillWidth: true; iconName: "system-search-symbolic"; title: "Image Search"; subtitle: "Visual search a screen region"; enabled: !root.capturePending; onClicked: root.triggerCapture(true, false, false, true) }
                            Item { Layout.fillHeight: true }
                        }

                        // ================= DETAIL: DAILY TOOLS =================
                        DailyTools {
                            anchors.fill: parent
                            visible: root.detailPage === "Daily Tools"
                        }

                        // ================= DETAIL: CLIPBOARD =================
                        ClipboardTools {
                            anchors.fill: parent
                            visible: root.opened && root.detailPage === "Clipboard"
                            shellState: root.shellState
                        }

                        // ================= VIEW: NOTIFICATIONS =================
                        ColumnLayout {
                            id: alertsView
                            anchors.fill: parent
                            spacing: 10
                            opacity: root.notificationsOpen ? 1 : 0
                            enabled: root.notificationsOpen
                            visible: opacity > 0
                            y: root.notificationsOpen ? 0 : 8

                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                            ToggleRow {
                                Layout.fillWidth: true
                                iconName: (root.shellState?.doNotDisturb ?? false)
                                    ? "notifications-disabled-symbolic"
                                    : "preferences-system-notifications-symbolic"
                                title: "Do Not Disturb"
                                subtitle: (root.shellState?.doNotDisturb ?? false) ? "Popups are silenced" : "Showing incoming popups"
                                checked: root.shellState?.doNotDisturb ?? false
                                onToggled: if (root.shellState) root.shellState.doNotDisturb = !root.shellState.doNotDisturb
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "RECENT"; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: LivePalette.color.onSurfaceVariant }
                                Item { Layout.fillWidth: true }
                                SettingsActionButton {
                                    visible: history.count > 0
                                    implicitHeight: 30; horizontalPadding: 12
                                    text: "Clear All"
                                    onClicked: {
                                        if (root.shellState) {
                                            root.shellState.notificationHistory = [];
                                            root.shellState.unreadNotifications = 0;
                                        }
                                    }
                                }
                            }

                            Item {
                                visible: history.count === 0
                                Layout.fillWidth: true; Layout.fillHeight: true
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 8
                                    SymbolIcon { Layout.alignment: Qt.AlignHCenter; implicitWidth: 28; implicitHeight: 28; iconName: "notifications-disabled-symbolic"; tint: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.4) }
                                    Text { text: "All caught up"; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 13 }
                                }
                            }

                            ListView {
                                id: history
                                visible: count > 0
                                Layout.fillWidth: true; Layout.fillHeight: true
                                clip: true; spacing: 8
                                model: root.groupNotifications(root.shellState?.notificationHistory ?? [])
                                ScrollBar.vertical: ScrollBar { active: true }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: history.width - 8
                                    implicitHeight: notifCol.implicitHeight + 22
                                    radius: 20
                                    color: LivePalette.color.surfaceContainer

                                    ColumnLayout {
                                        id: notifCol
                                        anchors.fill: parent; anchors.margins: 12; spacing: 4
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            Text {
                                                text: index === 0 || history.model[index - 1]?.app !== modelData.app ? modelData.app : ""
                                                textFormat: Text.PlainText
                                                color: LivePalette.color.primary
                                                font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text { text: modelData.time; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 11 }
                                        }
                                        Text { Layout.fillWidth: true; text: modelData.title; textFormat: Text.PlainText; color: LivePalette.color.onSurface; font.pixelSize: 13; font.weight: Font.Medium; wrapMode: Text.Wrap }
                                        Text { Layout.fillWidth: true; visible: !!text; text: modelData.body; textFormat: Text.PlainText; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
