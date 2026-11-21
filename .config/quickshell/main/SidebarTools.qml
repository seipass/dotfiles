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
    property int brightness: -1
    property int pendingBrightness: -1
    property bool brightnessUserChanged: false
    property string bluetoothStatus: ""
    property var bluetoothDevices: []
    property var connectedBluetooth: []
    property string bluetoothError: ""
    property string wifiStatus: ""
    property string currentSsid: ""
    property string wifiError: ""
    property var wifiProfiles: []
    property bool capturePending: false
    property bool captureWithoutEditor: false
    property bool captureText: false
    property bool translateText: false
    property bool imageSearch: false

    readonly property var activePlayer: Mpris.players.values.find(p => p.isPlaying)
        || Mpris.players.values[0] || null
    readonly property bool bluetoothPowered: /Powered:\s+yes/.test(bluetoothStatus)
    readonly property string networkLabel: root.shellState ? (root.shellState.networkLabel || "OFF") : "OFF"
    readonly property bool networkConnected: networkLabel !== "OFF" && networkLabel !== ""
    function isBluetoothConnected(address) {
        return connectedBluetooth.some(item => item.address.toLowerCase() === address.toLowerCase());
    }
    function requestBrightness(percent) {
        const clamped = Math.max(1, Math.min(100, Math.round(percent)));
        brightness = clamped;
        pendingBrightness = clamped;
        brightnessUserChanged = true;
        brightnessDebounce.restart();
    }
    readonly property string pageSubtitle: {
        if (notificationsOpen) return "Recent activity and alerts";
        switch (detailPage) {
        case "Capture": return "Screenshot, OCR & visual search";
        case "Network": return "Wi-Fi & saved connections";
        case "Bluetooth": return "Wireless audio & peripherals";
        case "Brightness": return "Display backlight & DDC/CI";
        case "Windows": return "Workspaces & active windows";
        case "Clipboard": return "Recent copied text snippets";
        case "Daily Tools": return "Focus timer, stopwatch & notes";
        case "Wallpapers": return "Pick from ~/Pictures";
        case "System": return "Diagnostics & system updates";
        case "Bar Appearance": return "Customize shell bar & widgets";
        default: return "Control center & utilities";
        }
    }

    readonly property var parsedWifiNetworks: {
        if (!wifiStatus) return [];
        const bySsid = new Map();
        for (const raw of wifiStatus.split("\n")) {
            if (!raw.trim()) continue;
            // nmcli -t escapes ':' inside values as '\:'
            const parts = raw.replace(/\\:/g, "\u0000").split(":").map(s => s.replace(/\u0000/g, ":"));
            if (parts.length < 4) continue;
            const inUse = parts[0].trim() === "*";
            const ssid = parts[1].trim();
            const signal = Number(parts[2]) || 0;
            const security = parts.slice(3).join(":").trim();
            if (!ssid) continue;
            const existing = bySsid.get(ssid);
            if (!existing || inUse || (!existing.inUse && signal > existing.signal)) {
                bySsid.set(ssid, { inUse, ssid, signal, security });
            }
        }
        return Array.from(bySsid.values()).sort((a, b) => {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
            return b.signal - a.signal;
        });
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

    function connectToSsid(ssid) {
        wifiError = "";
        const saved = wifiProfiles.find(item => item[2] === ssid);
        if (saved) {
            connectWifi.uuid = saved[1];
            connectWifi.running = true;
        } else {
            closeTools();
            Quickshell.execDetached(["kitty", "--hold", "--title", "Join Wi-Fi",
                "nmcli", "--ask", "device", "wifi", "connect", ssid]);
        }
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
            setBrightness.step = "set";
            setBrightness.targetValue = String(root.pendingBrightness);
            setBrightness.running = true;
        }
    }
    Process {
        id: setBrightness
        property string step: ""
        property string targetValue: ""
        command: step === "set"
            ? ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/monitor-brightness.py", root.screen?.name ?? "", "set", targetValue]
            : ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/monitor-brightness.py", root.screen?.name ?? "", step]
        onExited: readBrightness.running = true
    }
    Process {
        id: pairedDevices
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: root.bluetoothDevices = text.split("\n").map(line =>
                line.match(/^Device ([0-9a-f:]{17}) (.+)$/i)).filter(Boolean)
        }
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
        id: connectBluetooth
        property string address: ""
        property string action: "connect"
        command: ["timeout", "20s", "bluetoothctl", action, address]
        onExited: code => {
            root.bluetoothError = code === 0 ? "" : "Could not " + action + " the selected device.";
            connectedDevices.running = true;
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
    Process {
        id: savedWifi
        command: ["nmcli", "-t", "--escape", "no", "-f", "UUID,TYPE,NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiProfiles = text.split("\n").map(line =>
                line.match(/^([a-f0-9-]{36}):(?:802-11-wireless|wifi):(.+)$/i)).filter(Boolean)
        }
    }
    Process {
        id: connectWifi
        property string uuid: ""
        command: ["nmcli", "--wait", "20", "connection", "up", "uuid", uuid]
        onExited: code => {
            root.wifiError = code === 0 ? "" : "Could not connect. Check the saved profile in Connections.";
            wifiScan.running = true;
            activeWifi.running = true;
        }
    }
    Process {
        id: wifiScan
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector { onStreamFinished: root.wifiStatus = text.trim() }
    }
    Process {
        id: bluetooth
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.bluetoothStatus = text.trim()
        }
    }
    Process {
        id: bluetoothPower
        property bool enable: false
        command: ["bluetoothctl", "power", enable ? "on" : "off"]
        onExited: {
            bluetooth.running = true;
            connectedDevices.running = true;
        }
    }

    onDetailPageChanged: {
        if (opened && !notificationsOpen) detailMotion.restart();
        if (detailPage === "Brightness") readBrightness.running = true;
        if (detailPage === "Bluetooth") {
            bluetooth.running = true;
            pairedDevices.running = true;
            connectedDevices.running = true;
        }
        if (detailPage === "Network") {
            wifiScan.running = true;
            savedWifi.running = true;
            activeWifi.running = true;
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
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: opened && (detailPage === "Daily Tools" || detailPage === "Clipboard" || detailPage === "Network") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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

                                // Status & Primary Quick Tiles (2x2)
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
                                        onClicked: root.detailPage = "Network"
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
                                        onClicked: root.detailPage = "Bluetooth"
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

                                // Now Playing Card (M3 Filled Tonal Card)
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
                                            radius: 12
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
                                                implicitWidth: 30
                                                implicitHeight: 30
                                                radius: 15
                                                iconName: "media-skip-backward-symbolic"
                                                label: "Previous track"
                                                onClicked: if (root.activePlayer) root.activePlayer.previous()
                                            }
                                            Rectangle {
                                                width: 34
                                                height: 34
                                                radius: 17
                                                color: playMouse.pressed ? Qt.darker(LivePalette.color.primary, 1.12)
                                                     : playMouse.containsMouse ? Qt.lighter(LivePalette.color.primary, 1.08)
                                                     : LivePalette.color.primary
                                                scale: playMouse.pressed ? 0.94 : 1.0
                                                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                                SymbolIcon {
                                                    anchors.centerIn: parent
                                                    implicitWidth: 16
                                                    implicitHeight: 16
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
                                                implicitWidth: 30
                                                implicitHeight: 30
                                                radius: 15
                                                iconName: "media-skip-forward-symbolic"
                                                label: "Next track"
                                                onClicked: if (root.activePlayer) root.activePlayer.next()
                                            }
                                        }
                                    }
                                }

                                // Audio & Display Card (M3 Filled Card)
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

                                        // Volume
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 28
                                                    Layout.preferredHeight: 28
                                                    radius: 14
                                                    color: muteMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"

                                                    SymbolIcon {
                                                        anchors.centerIn: parent
                                                        implicitWidth: 16
                                                        implicitHeight: 16
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

                                                Text {
                                                    text: "Volume"
                                                    color: LivePalette.color.onSurface
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                }

                                                Item { Layout.fillWidth: true }

                                                Rectangle {
                                                    radius: 8
                                                    color: LivePalette.color.surfaceContainerHigh
                                                    implicitWidth: volVal.implicitWidth + 12
                                                    implicitHeight: 22

                                                    Text {
                                                        id: volVal
                                                        anchors.centerIn: parent
                                                        text: root.shellState?.volumeMuted ? "Muted" : (root.shellState?.volumePercent ?? 0) + "%"
                                                        color: root.shellState?.volumeMuted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                    }
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                implicitHeight: 24

                                                BarSlider {
                                                    anchors.fill: parent
                                                    from: 0
                                                    to: 100
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

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: Qt.alpha(LivePalette.color.outlineVariant, 0.4)
                                        }

                                        // Brightness
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 28
                                                    Layout.preferredHeight: 28
                                                    radius: 14
                                                    color: brightMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"

                                                    SymbolIcon {
                                                        anchors.centerIn: parent
                                                        implicitWidth: 16
                                                        implicitHeight: 16
                                                        iconName: "display-brightness-symbolic"
                                                        tint: root.brightness >= 0 ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                                    }

                                                    MouseArea {
                                                        id: brightMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.detailPage = "Brightness"
                                                    }
                                                }

                                                Text {
                                                    text: "Brightness"
                                                    color: LivePalette.color.onSurface
                                                    font.pixelSize: 13
                                                    font.weight: Font.Medium
                                                }

                                                Item { Layout.fillWidth: true }

                                                Rectangle {
                                                    radius: 8
                                                    color: LivePalette.color.surfaceContainerHigh
                                                    implicitWidth: brightVal.implicitWidth + 12
                                                    implicitHeight: 22

                                                    Text {
                                                        id: brightVal
                                                        anchors.centerIn: parent
                                                        text: readBrightness.running && root.brightness < 0 ? "…"
                                                            : root.brightness >= 0 ? root.brightness + "%" : "N/A"
                                                        color: root.brightness >= 0 ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                    }
                                                }
                                            }

                                            Item {
                                                visible: root.brightness >= 0
                                                Layout.fillWidth: true
                                                implicitHeight: 24

                                                BarSlider {
                                                    anchors.fill: parent
                                                    from: 1
                                                    to: 100
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

                                // Utilities Section (Direct 1-click access, no extra submenu)
                                Text {
                                    Layout.fillWidth: true
                                    text: "UTILITIES"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 7
                                    columnSpacing: 7

                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "system-search-symbolic"
                                        title: "App Launcher"
                                        onClicked: {
                                            root.closeTools();
                                            root.launcher.toggleLauncher(false);
                                        }
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "view-grid-symbolic"
                                        title: "Windows"
                                        onClicked: root.detailPage = "Windows"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "edit-paste-symbolic"
                                        title: "Clipboard"
                                        onClicked: root.detailPage = "Clipboard"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "preferences-system-time-symbolic"
                                        title: "Daily Tools"
                                        onClicked: root.detailPage = "Daily Tools"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "image-x-generic-symbolic"
                                        title: "Wallpapers"
                                        onClicked: root.detailPage = "Wallpapers"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "computer-symbolic"
                                        title: "System"
                                        onClicked: root.detailPage = "System"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "preferences-desktop-theme-symbolic"
                                        title: "Bar & Shell"
                                        onClicked: root.detailPage = "Bar Appearance"
                                    }
                                    CompactTile {
                                        Layout.fillWidth: true
                                        iconName: "preferences-system-symbolic"
                                        title: "Settings"
                                        onClicked: {
                                            root.closeTools();
                                            root.shellState.openSettings(root.screen);
                                        }
                                    }
                                }

                                // Quick Toggle
                                Text {
                                    Layout.fillWidth: true
                                    text: "WORKSPACE"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }

                                ToggleRow {
                                    Layout.fillWidth: true
                                    iconName: "preferences-system-time-symbolic"
                                    title: "Desktop Clock"
                                    subtitle: "Show clock overlay on wallpaper"
                                    checked: root.shellState?.desktopClock ?? false
                                    onToggled: if (root.shellState) root.shellState.setDesktopClock(!root.shellState.desktopClock)
                                }

                                Item { implicitHeight: 4 }
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
                                        radius: 14
                                        color: LivePalette.color.surfaceContainer
                                        border.width: 1
                                        border.color: winMouse.containsMouse ? LivePalette.color.primary : Qt.alpha(LivePalette.color.onSurface, 0.08)
                                        clip: true
                                        Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }

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
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
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
                                            id: winMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
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

                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "camera-photo-symbolic"
                                title: "Screenshot (Editor)"
                                subtitle: "Capture & annotate with Flameshot"
                                enabled: !root.capturePending
                                onClicked: root.triggerCapture(false, false, false, false)
                            }
                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "document-save-symbolic"
                                title: "Save Region"
                                subtitle: "Select an area and save immediately"
                                enabled: !root.capturePending
                                onClicked: root.triggerCapture(true, false, false, false)
                            }
                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "edit-find-symbolic"
                                title: "Read Screen Text (OCR)"
                                subtitle: "Extract text from a selected area"
                                enabled: !root.capturePending
                                onClicked: root.triggerCapture(true, true, false, false)
                            }
                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "preferences-desktop-locale-symbolic"
                                title: "Translate Screen Text"
                                subtitle: "Recognize text & open Google Translate"
                                enabled: !root.capturePending
                                onClicked: translationConsent.open()
                            }
                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "system-search-symbolic"
                                title: "Image Search"
                                subtitle: "Visual search a screen region"
                                enabled: !root.capturePending
                                onClicked: root.triggerCapture(true, false, false, true)
                            }
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
                        }

                        // ================= DETAIL: WALLPAPERS =================
                        WallpaperBrowser {
                            anchors.fill: parent
                            visible: root.detailPage === "Wallpapers"
                            selected: root.shellState?.wallpaperPath ?? ""
                            onChosen: path => root.shellState.setWallpaper(path)
                        }

                        // ================= DETAIL: SYSTEM =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "System"
                            spacing: 8

                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "computer-symbolic"
                                title: "System Information"
                                subtitle: "Hardware, OS & session summary"
                                onClicked: {
                                    root.closeTools();
                                    root.shellState.openSystemInfo(root.screen);
                                }
                            }
                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "dialog-warning-symbolic"
                                title: "Session Errors"
                                subtitle: "Recent journalctl user warnings"
                                onClicked: {
                                    root.closeTools();
                                    Quickshell.execDetached(["kitty", "--hold", "--title", "Session errors",
                                        "journalctl", "--user", "-b", "-p", "warning", "-n", "80", "--no-pager"]);
                                }
                            }
                            ToolCard {
                                Layout.fillWidth: true
                                iconName: "software-update-available-symbolic"
                                title: "Check System Updates"
                                subtitle: "List pending Arch package updates"
                                onClicked: {
                                    root.closeTools();
                                    Quickshell.execDetached(["kitty", "--hold", "--title", "Check system updates", "sh", "-c",
                                        "if command -v checkupdates >/dev/null; then checkupdates; else echo 'Install pacman-contrib to check for updates.'; fi"]);
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }

                        // ================= DETAIL: BRIGHTNESS =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Brightness"
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 22
                                color: LivePalette.color.surfaceContainer
                                implicitHeight: brightDetailCol.implicitHeight + 28

                                ColumnLayout {
                                    id: brightDetailCol
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true
                                        SymbolIcon {
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            iconName: "display-brightness-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.screen?.name ?? "Display"
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: LivePalette.color.onSurface
                                        }
                                        Text {
                                            text: readBrightness.running && root.brightness < 0 ? "…"
                                                : root.brightness >= 0 ? root.brightness + "%" : "N/A"
                                            font.family: "Ndot 55"
                                            font.pixelSize: 22
                                            color: LivePalette.color.primary
                                        }
                                    }

                                    // Interactive Brightness Slider
                                    BarSlider {
                                        visible: root.brightness >= 0
                                        Layout.fillWidth: true
                                        from: 1
                                        to: 100
                                        value: Math.max(1, root.brightness)
                                        onMoved: root.requestBrightness(value)
                                    }

                                    // Quick Presets
                                    RowLayout {
                                        visible: root.brightness >= 0
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: [25, 50, 75, 100]
                                            delegate: SettingsActionButton {
                                                required property int modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 32
                                                horizontalPadding: 6
                                                primary: Math.abs(root.brightness - modelData) <= 2
                                                text: modelData + "%"
                                                onClicked: root.requestBrightness(modelData)
                                            }
                                        }
                                    }

                                    Text {
                                        visible: root.brightness < 0 && !readBrightness.running
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        font.pixelSize: 12
                                        text: "Brightness unavailable on this monitor. Check DDC/CI and ddcutil, or brightnessctl for an internal display."
                                        color: LivePalette.color.onSurfaceVariant
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        enabled: root.brightness >= 0 && !setBrightness.running && !readBrightness.running

                                        SettingsActionButton {
                                            Layout.fillWidth: true
                                            text: "− 5%"
                                            onClicked: {
                                                root.brightnessUserChanged = true;
                                                setBrightness.step = "down";
                                                setBrightness.running = true;
                                            }
                                        }
                                        SettingsActionButton {
                                            Layout.fillWidth: true
                                            primary: true
                                            text: "+ 5%"
                                            onClicked: {
                                                root.brightnessUserChanged = true;
                                                setBrightness.step = "up";
                                                setBrightness.running = true;
                                            }
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }

                        // ================= DETAIL: BAR APPEARANCE =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Bar Appearance"
                            spacing: 8

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
                            Item { Layout.fillHeight: true }
                        }

                        // ================= DETAIL: NETWORK =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Network"
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SettingsActionButton {
                                    Layout.fillWidth: true
                                    iconName: "view-refresh-symbolic"
                                    text: wifiScan.running ? "Scanning…" : "Scan Wi-Fi"
                                    enabled: !wifiScan.running
                                    onClicked: {
                                        wifiScan.running = true;
                                        savedWifi.running = true;
                                    }
                                }
                                SettingsActionButton {
                                    iconName: "preferences-system-network-symbolic"
                                    text: "Editor"
                                    onClicked: {
                                        root.closeTools();
                                        Quickshell.execDetached(["nm-connection-editor"]);
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                TextField {
                                    id: newSsid
                                    Layout.fillWidth: true
                                    placeholderText: "Join hidden or new SSID…"
                                    Accessible.name: "New network name"
                                    implicitHeight: 38
                                    leftPadding: 12
                                    background: Rectangle {
                                        radius: 12
                                        color: LivePalette.color.surfaceContainer
                                        border.color: newSsid.activeFocus ? LivePalette.color.primary : LivePalette.color.outlineVariant
                                        Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }
                                    }
                                }
                                SettingsActionButton {
                                    text: "Join"
                                    primary: true
                                    enabled: newSsid.text.length > 0 && !newSsid.text.startsWith("-") && !connectWifi.running
                                    onClicked: root.connectToSsid(newSsid.text)
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: !!root.wifiError
                                text: root.wifiError
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                color: LivePalette.color.error
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "AVAILABLE NETWORKS"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2
                                color: LivePalette.color.onSurfaceVariant
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 6
                                model: root.parsedWifiNetworks
                                ScrollBar.vertical: ScrollBar {}

                                delegate: ToolCard {
                                    required property var modelData
                                    width: ListView.view.width - 4
                                    iconName: modelData.signal >= 65 ? "network-wireless-signal-excellent-symbolic"
                                            : modelData.signal >= 40 ? "network-wireless-signal-good-symbolic"
                                            : "network-wireless-signal-weak-symbolic"
                                    title: modelData.ssid
                                    subtitle: (modelData.security || "Open") + " · " + modelData.signal + "%"
                                    badge: modelData.inUse ? "Connected" : ""
                                    active: modelData.inUse
                                    busy: connectWifi.running
                                    onClicked: if (!modelData.inUse) root.connectToSsid(modelData.ssid)
                                }

                                Label {
                                    anchors.centerIn: parent
                                    visible: parent.count === 0
                                    text: wifiScan.running ? "Scanning nearby networks…" : "No Wi-Fi networks found"
                                    color: LivePalette.color.onSurfaceVariant
                                }
                            }
                        }

                        // ================= DETAIL: BLUETOOTH =================
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.detailPage === "Bluetooth"
                            spacing: 10

                            ToggleRow {
                                Layout.fillWidth: true
                                iconName: "bluetooth-symbolic"
                                title: "Bluetooth"
                                subtitle: bluetooth.running ? "Checking controller…"
                                        : !root.bluetoothStatus ? "No controller found"
                                        : root.bluetoothPowered ? "Discoverable & active" : "Turned off"
                                checked: root.bluetoothPowered
                                enabled: !!root.bluetoothStatus && !bluetooth.running && !bluetoothPower.running
                                onToggled: {
                                    bluetoothPower.enable = !root.bluetoothPowered;
                                    bluetoothPower.running = true;
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SettingsActionButton {
                                    Layout.fillWidth: true
                                    iconName: "view-refresh-symbolic"
                                    text: "Refresh"
                                    enabled: !bluetooth.running
                                    onClicked: {
                                        bluetooth.running = true;
                                        pairedDevices.running = true;
                                        connectedDevices.running = true;
                                    }
                                }
                                SettingsActionButton {
                                    Layout.fillWidth: true
                                    iconName: "list-add-symbolic"
                                    text: "Pair New"
                                    onClicked: {
                                        root.closeTools();
                                        Quickshell.execDetached(["kitty", "--title", "Bluetooth pairing",
                                            "bluetoothctl", "--agent", "KeyboardDisplay"]);
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: !!root.bluetoothError
                                text: root.bluetoothError
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                                color: LivePalette.color.error
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "PAIRED DEVICES"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2
                                color: LivePalette.color.onSurfaceVariant
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 6
                                model: root.bluetoothDevices
                                ScrollBar.vertical: ScrollBar {}

                                delegate: ToolCard {
                                    required property var modelData
                                    readonly property bool isConnected: root.isBluetoothConnected(modelData[1])
                                    readonly property bool isWorking: connectBluetooth.running && connectBluetooth.address === modelData[1]
                                    width: ListView.view.width - 4
                                    iconName: "bluetooth-symbolic"
                                    title: modelData[2]
                                    subtitle: isConnected ? "Connected · Tap to disconnect" : modelData[1]
                                    badge: isWorking ? (connectBluetooth.action === "disconnect" ? "Disconnecting…" : "Connecting…")
                                         : isConnected ? "Connected" : "Connect"
                                    active: isConnected
                                    busy: connectBluetooth.running
                                    onClicked: {
                                        root.bluetoothError = "";
                                        connectBluetooth.address = modelData[1];
                                        connectBluetooth.action = isConnected ? "disconnect" : "connect";
                                        connectBluetooth.running = true;
                                    }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    visible: parent.count === 0
                                    text: "No paired devices yet"
                                    color: LivePalette.color.onSurfaceVariant
                                }
                            }
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
                                Text {
                                    text: "RECENT"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    color: LivePalette.color.onSurfaceVariant
                                }
                                Item { Layout.fillWidth: true }
                                SettingsActionButton {
                                    visible: history.count > 0
                                    implicitHeight: 30
                                    horizontalPadding: 12
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
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    SymbolIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        iconName: "notifications-disabled-symbolic"
                                        tint: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.4)
                                    }
                                    Text {
                                        text: "All caught up"
                                        color: LivePalette.color.onSurfaceVariant
                                        font.pixelSize: 13
                                    }
                                }
                            }

                            ListView {
                                id: history
                                visible: count > 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 8
                                add: Transition {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.standard; easing.type: Easing.OutCubic }
                                }
                                displaced: Transition {
                                    NumberAnimation { property: "y"; duration: Theme.motion.standard; easing.type: Easing.OutQuint }
                                }
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
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: index === 0 || history.model[index - 1]?.app !== modelData.app ? modelData.app : ""
                                                textFormat: Text.PlainText
                                                color: LivePalette.color.primary
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: modelData.time
                                                color: LivePalette.color.onSurfaceVariant
                                                font.pixelSize: 11
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            textFormat: Text.PlainText
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            wrapMode: Text.Wrap
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: !!text
                                            text: modelData.body
                                            textFormat: Text.PlainText
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
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
}
