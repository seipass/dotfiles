import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "Theme.js" as Theme

Window {
    id: root
    FontLoader { id: settingsFont; source: "fonts/GoogleSansFlex.ttf" }
    readonly property string uiFont: settingsFont.status === FontLoader.Ready ? settingsFont.name : Qt.application.font.family

    // Live audio state passed from shell.qml
    property int volumePercent: 0
    property bool volumeMuted: false
    property bool volumeAvailable: false

    // Shared dotfiles/shell settings (edited from Quick Tools, persisted in dashboard.ini)
    property alias weatherCity: saved.weatherCity
    property alias wallpaper: saved.wallpaper
    property alias desktopClock: saved.desktopClock
    property alias showTray: saved.showTray
    property alias showTaskbar: saved.showTaskbar
    property alias paletteMode: saved.paletteMode
    property alias islandDisplay: saved.islandDisplay
    property alias islandPlugin: saved.islandPlugin
    property alias quotaInterval: saved.quotaInterval
    property alias quotaProvider: saved.quotaProvider
    property alias earthquakeInterval: saved.earthquakeInterval
    property alias page: persisted.page

    property string pendingPaletteMode: ""
    property string pendingPaletteSeed: ""
    property bool paletteQueued: false
    property bool paletteFailed: false

    // System Settings states
    property string wifiStatus: ""
    property string wifiError: ""
    property var wifiProfiles: []
    property string bluetoothStatus: ""
    property var bluetoothDevices: []
    property var connectedBluetooth: []
    property string bluetoothError: ""
    property int brightness: -1
    property int pendingBrightness: -1

    readonly property bool bluetoothPowered: /Powered:\s+yes/.test(bluetoothStatus)
    readonly property bool isCompact: width < 720
    readonly property int safePage: Math.max(0, Math.min(4, root.page))

    readonly property var parsedWifiNetworks: {
        if (!wifiStatus) return [];
        const bySsid = new Map();
        for (const raw of wifiStatus.split("\n")) {
            if (!raw.trim()) continue;
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

    function isBluetoothConnected(address) {
        return connectedBluetooth.some(item => item.address.toLowerCase() === address.toLowerCase());
    }

    function connectToSsid(ssid) {
        wifiError = "";
        const savedProf = wifiProfiles.find(item => item[2] === ssid);
        if (savedProf) {
            connectWifi.uuid = savedProf[1];
            connectWifi.running = true;
        } else {
            Quickshell.execDetached(["kitty", "--hold", "--title", "Join Wi-Fi",
                "nmcli", "--ask", "device", "wifi", "connect", ssid]);
        }
    }

    function requestBrightness(percent) {
        const clamped = Math.max(1, Math.min(100, Math.round(percent)));
        brightness = clamped;
        pendingBrightness = clamped;
        brightnessDebounce.restart();
    }

    function refreshCurrentPage() {
        if (safePage === 0) {
            if (!wifiScan.running) wifiScan.running = true;
            if (!savedWifi.running) savedWifi.running = true;
        } else if (safePage === 1) {
            if (!bluetooth.running) bluetooth.running = true;
            if (!pairedDevices.running) pairedDevices.running = true;
            if (!connectedDevices.running) connectedDevices.running = true;
        } else if (safePage === 2) {
            if (!readBrightness.running) readBrightness.running = true;
        }
    }

    Component.onCompleted: {
        if (saved.paletteColors) LivePalette.apply(saved.paletteColors);
        if (saved.paletteMode !== "auto" || !root.wallpaper) root.applyPalette(saved.paletteMode);
        if (persisted.page > 4) persisted.page = 4;
    }

    // ── Shared dotfiles helpers (used by Quick Tools) ────────────────────────
    property string pickerKind: ""
    property string pickerError: ""
    readonly property bool pickingFile: filePicker.running
    function chooseFile(kind) {
        if (filePicker.running) return;
        pickerError = "";
        pickerKind = kind;
        filePicker.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/portal-file-picker.py", kind];
        filePicker.running = true;
    }

    Process {
        id: filePicker
        stdout: StdioCollector {
            onStreamFinished: {
                const uri = this.text.trim();
                if (!uri.startsWith("file://")) return;
                if (root.pickerKind === "wallpaper") root.setWallpaper(uri);
                else if (root.pickerKind === "plugin") {
                    saved.islandPlugin = uri;
                    saved.islandDisplay = "custom";
                    saved.sync();
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) root.pickerError = "File selection was cancelled or failed.";
        }
    }

    property var citySuggestions: []
    property bool searchingCities: false
    function searchCity(query) {
        if (!query || query.trim().length < 2) {
            citySuggestions = [];
            searchingCities = false;
            return;
        }
        citySearchProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/city-search.py", query.trim()];
        citySearchProcess.running = true;
        searchingCities = true;
    }

    Process {
        id: citySearchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.citySuggestions = JSON.parse(this.text.trim()); }
                catch (_) { root.citySuggestions = []; }
                root.searchingCities = false;
            }
        }
        onExited: root.searchingCities = false
    }

    function runPalette() {
        paletteQueued = false;
        paletteProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/apply-palette.py", pendingPaletteMode, pendingPaletteSeed, "--sync-desktop"];
        paletteProcess.running = true;
    }

    IpcHandler {
        target: "palette"
        function status(): string { return saved.paletteMode + "|" + LivePalette.color.primary + "|" + saved.value("paletteMode", "?"); }
        function select(mode: string): void {
            if (["auto", "pink", "blue", "green"].includes(mode)) root.applyPalette(mode);
        }
    }

    function applyPalette(mode) {
        saved.paletteMode = mode;
        saved.setValue("paletteMode", mode);
        saved.sync();
        let seed = "#ffb0ca";
        let bestScore = -1;
        for (const c of wallpaperColors.colors) {
            const high = Math.max(c.r, c.g, c.b);
            const low = Math.min(c.r, c.g, c.b);
            const score = (high - low) * (1 - Math.abs((high + low) / 2 - 0.5));
            if (score > bestScore) { bestScore = score; seed = c.toString(); }
        }
        pendingPaletteMode = mode;
        pendingPaletteSeed = seed;
        paletteQueued = true;
        if (!paletteProcess.running) runPalette();
    }

    Process {
        id: paletteProcess
        property string resultText: ""
        stdout: StdioCollector { onStreamFinished: paletteProcess.resultText = this.text.trim() }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) console.warn("Could not generate palette: " + this.text.trim()) }
        onExited: function(exitCode) {
            if (!root.paletteQueued) {
                root.paletteFailed = exitCode !== 0 || !LivePalette.apply(resultText);
                if (!root.paletteFailed) {
                    saved.paletteColors = resultText;
                    saved.setValue("paletteColors", resultText);
                    saved.sync();
                }
            }
            resultText = "";
            if (root.paletteQueued) Qt.callLater(root.runPalette);
        }
    }

    function setWallpaper(path) { saved.wallpaper = path; saved.setValue("wallpaper", path); saved.sync(); }
    function setWeatherCity(city) { saved.weatherCity = city; saved.setValue("weatherCity", city); saved.sync(); }
    function setIslandDisplay(mode) { saved.islandDisplay = mode; saved.setValue("islandDisplay", mode); saved.sync(); }
    function setQuotaInterval(seconds) { saved.quotaInterval = seconds; saved.setValue("quotaInterval", seconds); saved.sync(); }
    function setQuotaProvider(providerId) { saved.quotaProvider = providerId; saved.setValue("quotaProvider", providerId); saved.sync(); }
    function setEarthquakeInterval(seconds) { saved.earthquakeInterval = seconds; saved.setValue("earthquakeInterval", seconds); saved.sync(); }

    // ── System Settings processes ────────────────────────────────────────────
    Process {
        id: wifiScan
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector { onStreamFinished: root.wifiStatus = text.trim() }
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
        }
    }
    Process {
        id: bluetooth
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector { onStreamFinished: root.bluetoothStatus = text.trim() }
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
        id: bluetoothPower
        property bool enable: false
        command: ["bluetoothctl", "power", enable ? "on" : "off"]
        onExited: { bluetooth.running = true; connectedDevices.running = true; }
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

    onPageChanged: {
        pageAnim.restart();
        if (visible) refreshCurrentPage();
    }

    ParallelAnimation {
        id: pageAnim
        NumberAnimation { target: pageContent; property: "opacity"; from: 0.35; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: pageContent; property: "y"; from: 14; to: 0; duration: 240; easing.type: Easing.OutCubic }
    }

    PersistentProperties {
        id: persisted
        reloadableId: "settingsWindowState"
        property int page: 0
    }

    function open(targetScreen) {
        const target = targetScreen && Array.from(Qt.application.screens).find(display => display.name === targetScreen.name);
        if (target && screen !== target) screen = target;
        show();
        requestActivate();
        refreshCurrentPage();
    }

    IpcHandler {
        target: "settings"
        function open(): void { root.open(null); }
        function openPage(pageIndex: int): void {
            root.page = Math.max(0, Math.min(4, pageIndex));
            root.open(null);
        }
        function close(): void { root.close(); }
    }

    Settings {
        id: saved
        location: "file://" + Quickshell.env("HOME") + "/.config/quickshell/main/dashboard.ini"
        category: "Dashboard"
        property string weatherCity: ""
        property string wallpaper: ""
        property bool desktopClock: false
        property bool showTray: true
        property bool showTaskbar: true
        property string paletteMode: "pink"
        property string paletteColors: ""
        property string islandDisplay: "music"
        property string islandPlugin: ""
        property int quotaInterval: 60
        property string quotaProvider: "auto"
        property int earthquakeInterval: 0
    }

    ColorQuantizer {
        id: wallpaperColors
        source: root.wallpaper
        depth: 3
        rescaleSize: 64
        onColorsChanged: if (saved.paletteMode === "auto" && root.wallpaper && colors.length) root.applyPalette("auto")
    }
    onWallpaperChanged: if (saved.paletteMode === "auto" && !wallpaper) applyPalette("auto")

    visible: false
    title: "System Settings"
    width: 960
    height: 660
    minimumWidth: 540
    minimumHeight: 460
    color: LivePalette.color.surface

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ================= Sidebar (M3 Navigation Drawer / Rail) =================
        Rectangle {
            Layout.preferredWidth: root.isCompact ? 80 : 248
            Layout.fillHeight: true
            color: LivePalette.color.surfaceContainer

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.isCompact ? 12 : 16
                spacing: 6

                RowLayout {
                    Layout.topMargin: 6
                    Layout.bottomMargin: 16
                    Layout.alignment: root.isCompact ? Qt.AlignHCenter : Qt.AlignLeft
                    spacing: 12

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: LivePalette.color.primaryContainer

                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 20
                            implicitHeight: 20
                            iconName: "preferences-system-symbolic"
                            tint: LivePalette.color.primary
                        }
                    }

                    ColumnLayout {
                        visible: !root.isCompact
                        spacing: 1
                        Text {
                            font.family: root.uiFont
                            text: "System"
                            color: LivePalette.color.onSurface
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Text {
                            font.family: root.uiFont
                            text: "Hardware & OS Settings"
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 11
                        }
                    }
                }

                Repeater {
                    model: [
                        { name: "Network",         icon: "network-wireless-symbolic" },
                        { name: "Bluetooth",       icon: "bluetooth-symbolic" },
                        { name: "Sound & Display", icon: "audio-volume-high-symbolic" },
                        { name: "Maintenance",     icon: "utilities-system-monitor-symbolic" },
                        { name: "About",           icon: "computer-symbolic" }
                    ]
                    delegate: Item {
                        id: nav
                        required property int index
                        required property var modelData
                        readonly property bool selected: root.safePage === nav.index
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.isCompact ? 52 : 48

                        Rectangle {
                            visible: !root.isCompact
                            anchors.fill: parent
                            radius: height / 2
                            color: nav.selected ? LivePalette.color.primaryContainer : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: LivePalette.color.onSurface
                                opacity: navMouse.pressed ? 0.12 : navMouse.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                SymbolIcon {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    iconName: nav.modelData.icon
                                    tint: nav.selected ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                }

                                Text {
                                    Layout.fillWidth: true
                                    font.family: root.uiFont
                                    text: nav.modelData.name
                                    color: nav.selected ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
                                    font.pixelSize: 14
                                    font.weight: nav.selected ? Font.DemiBold : Font.Medium
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.isCompact
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 32
                                radius: 16
                                color: nav.selected ? LivePalette.color.primaryContainer : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: LivePalette.color.onSurface
                                    opacity: navMouse.pressed ? 0.12 : navMouse.containsMouse ? 0.08 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                                }

                                SymbolIcon {
                                    anchors.centerIn: parent
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    iconName: nav.modelData.icon
                                    tint: nav.selected ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                }
                            }
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = nav.index
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ================= Content Area =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: pageScroll
                anchors.fill: parent
                clip: true
                contentHeight: pageContent.implicitHeight + 80
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                Connections {
                    target: root
                    function onPageChanged() { pageScroll.contentY = 0; }
                }

                ColumnLayout {
                    id: pageContent
                    x: root.isCompact ? 20 : 36
                    y: 0
                    width: pageScroll.width - (root.isCompact ? 40 : 72)
                    spacing: 20

                    Item { height: root.isCompact ? 16 : 26 }

                    // Page Header
                    ColumnLayout {
                        spacing: 4
                        Text {
                            font.family: Theme.font.display
                            text: ["Network", "Bluetooth", "Sound & Display", "Maintenance", "About"][root.safePage]
                            color: LivePalette.color.onSurface
                            font.pixelSize: root.isCompact ? 22 : 26
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            text: [
                                "Manage Wi-Fi networks, saved connections, and NetworkManager profiles.",
                                "Control Bluetooth power, connect paired peripherals, or pair new devices.",
                                "Adjust PipeWire audio volume and monitor backlight / DDC/CI brightness.",
                                "Inspect session logs, check Arch package updates, and manage shell services.",
                                "Hardware, kernel, display, and operating system specifications."
                            ][root.safePage]
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }
                    }

                    // ================= PAGE 0: NETWORK =================
                    ColumnLayout {
                        visible: root.safePage === 0
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 24
                            color: LivePalette.color.surfaceContainer
                            implicitHeight: netCtrlCol.implicitHeight + 36

                            ColumnLayout {
                                id: netCtrlCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    SettingsActionButton {
                                        primary: true
                                        iconName: "view-refresh-symbolic"
                                        text: wifiScan.running ? "Scanning…" : "Scan Wi-Fi"
                                        enabled: !wifiScan.running
                                        onClicked: { wifiScan.running = true; savedWifi.running = true; }
                                    }
                                    SettingsActionButton {
                                        iconName: "preferences-system-network-symbolic"
                                        text: "Connection Editor"
                                        onClicked: Quickshell.execDetached(["nm-connection-editor"])
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    TextField {
                                        id: newSsid
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        font.family: root.uiFont
                                        font.pixelSize: 13
                                        placeholderText: "Join hidden or new SSID…"
                                        color: LivePalette.color.onSurface
                                        placeholderTextColor: LivePalette.color.onSurfaceVariant
                                        leftPadding: 16
                                        background: Rectangle {
                                            radius: 16
                                            color: LivePalette.color.surfaceContainerHigh
                                            border.width: newSsid.activeFocus ? 2 : 1
                                            border.color: newSsid.activeFocus ? LivePalette.color.primary : LivePalette.color.outlineVariant
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }
                                    SettingsActionButton {
                                        text: "Join"
                                        primary: true
                                        enabled: newSsid.text.length > 0 && !newSsid.text.startsWith("-") && !connectWifi.running
                                        onClicked: root.connectToSsid(newSsid.text)
                                    }
                                }

                                Text {
                                    visible: !!root.wifiError
                                    Layout.fillWidth: true
                                    text: root.wifiError
                                    color: LivePalette.color.error
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "AVAILABLE WI-FI NETWORKS"
                                font.family: root.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2
                                color: LivePalette.color.onSurfaceVariant
                            }

                            Repeater {
                                model: root.parsedWifiNetworks
                                delegate: ToolCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    iconName: modelData.signal >= 65 ? "network-wireless-signal-excellent-symbolic"
                                            : modelData.signal >= 40 ? "network-wireless-signal-good-symbolic"
                                            : "network-wireless-signal-weak-symbolic"
                                    title: modelData.ssid
                                    subtitle: (modelData.security || "Open") + " · Signal " + modelData.signal + "%"
                                    badge: modelData.inUse ? "Connected" : "Connect"
                                    active: modelData.inUse
                                    busy: connectWifi.running
                                    onClicked: if (!modelData.inUse) root.connectToSsid(modelData.ssid)
                                }
                            }

                            Text {
                                visible: root.parsedWifiNetworks.length === 0
                                text: wifiScan.running ? "Scanning nearby Wi-Fi networks…" : "No Wi-Fi networks found."
                                font.family: root.uiFont
                                font.pixelSize: 13
                                color: LivePalette.color.onSurfaceVariant
                            }
                        }
                    }

                    // ================= PAGE 1: BLUETOOTH =================
                    ColumnLayout {
                        visible: root.safePage === 1
                        Layout.fillWidth: true
                        spacing: 16

                        ToggleRow {
                            Layout.fillWidth: true
                            iconName: "bluetooth-symbolic"
                            title: "Bluetooth"
                            subtitle: bluetooth.running ? "Checking controller…"
                                    : !root.bluetoothStatus ? "No Bluetooth controller found"
                                    : root.bluetoothPowered ? "Controller powered on" : "Turned off"
                            checked: root.bluetoothPowered
                            enabled: !!root.bluetoothStatus && !bluetooth.running && !bluetoothPower.running
                            onToggled: {
                                bluetoothPower.enable = !root.bluetoothPowered;
                                bluetoothPower.running = true;
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            SettingsActionButton {
                                iconName: "view-refresh-symbolic"
                                text: "Refresh"
                                enabled: !bluetooth.running
                                onClicked: { bluetooth.running = true; pairedDevices.running = true; connectedDevices.running = true; }
                            }
                            SettingsActionButton {
                                primary: true
                                iconName: "list-add-symbolic"
                                text: "Pair New Device"
                                onClicked: Quickshell.execDetached(["kitty", "--title", "Bluetooth pairing",
                                    "bluetoothctl", "--agent", "KeyboardDisplay"])
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            visible: !!root.bluetoothError
                            Layout.fillWidth: true
                            text: root.bluetoothError
                            color: LivePalette.color.error
                            font.family: root.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "PAIRED DEVICES"
                                font.family: root.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2
                                color: LivePalette.color.onSurfaceVariant
                            }

                            Repeater {
                                model: root.bluetoothDevices
                                delegate: ToolCard {
                                    required property var modelData
                                    readonly property bool isConnected: root.isBluetoothConnected(modelData[1])
                                    readonly property bool isWorking: connectBluetooth.running && connectBluetooth.address === modelData[1]
                                    Layout.fillWidth: true
                                    iconName: "bluetooth-symbolic"
                                    title: modelData[2]
                                    subtitle: isConnected ? "Connected · Click to disconnect" : modelData[1]
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
                            }

                            Text {
                                visible: root.bluetoothDevices.length === 0
                                text: "No paired devices yet."
                                font.family: root.uiFont
                                font.pixelSize: 13
                                color: LivePalette.color.onSurfaceVariant
                            }
                        }
                    }

                    // ================= PAGE 2: SOUND & DISPLAY =================
                    ColumnLayout {
                        visible: root.safePage === 2
                        Layout.fillWidth: true
                        spacing: 16

                        // Audio Card
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 24
                            color: LivePalette.color.surfaceContainer
                            implicitHeight: audioCardCol.implicitHeight + 36

                            ColumnLayout {
                                id: audioCardCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Rectangle {
                                        width: 40; height: 40; radius: 20
                                        color: LivePalette.color.primaryContainer
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 20; implicitHeight: 20
                                            iconName: root.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "Master Volume"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: root.volumeMuted ? "Muted" : root.volumePercent + "% output level"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                    SettingsActionButton {
                                        text: root.volumeMuted ? "Unmute" : "Mute"
                                        onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                    }
                                    SettingsActionButton {
                                        primary: true
                                        iconName: "audio-volume-high-symbolic"
                                        text: "Mixer"
                                        onClicked: Quickshell.execDetached(["pavucontrol"])
                                    }
                                }

                                BarSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 100
                                    value: root.volumePercent
                                    enabled: root.volumeAvailable
                                    onMoved: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)])
                                }
                            }
                        }

                        // Display Brightness Card
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 24
                            color: LivePalette.color.surfaceContainer
                            implicitHeight: dispCardCol.implicitHeight + 36

                            ColumnLayout {
                                id: dispCardCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Rectangle {
                                        width: 40; height: 40; radius: 20
                                        color: LivePalette.color.primaryContainer
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 20; implicitHeight: 20
                                            iconName: "display-brightness-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "Display Brightness (" + (root.screen?.name ?? "Monitor") + ")"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: readBrightness.running && root.brightness < 0 ? "Checking DDC/CI & backlight…"
                                                : root.brightness >= 0 ? root.brightness + "%" : "Unavailable on this display"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                BarSlider {
                                    visible: root.brightness >= 0
                                    Layout.fillWidth: true
                                    from: 1; to: 100
                                    value: Math.max(1, root.brightness)
                                    onMoved: root.requestBrightness(value)
                                }

                                RowLayout {
                                    visible: root.brightness >= 0
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: [25, 50, 75, 100]
                                        delegate: SettingsActionButton {
                                            required property int modelData
                                            Layout.fillWidth: true
                                            primary: Math.abs(root.brightness - modelData) <= 2
                                            text: modelData + "%"
                                            onClicked: root.requestBrightness(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ================= PAGE 3: MAINTENANCE =================
                    ColumnLayout {
                        visible: root.safePage === 3
                        Layout.fillWidth: true
                        spacing: 10

                        ToolCard {
                            Layout.fillWidth: true
                            iconName: "utilities-system-monitor-symbolic"
                            title: "Task Manager (htop)"
                            subtitle: "Monitor live CPU, memory, and running processes"
                            onClicked: Quickshell.execDetached(["kitty", "-e", "htop"])
                        }
                        ToolCard {
                            Layout.fillWidth: true
                            iconName: "dialog-warning-symbolic"
                            title: "Session Errors (journalctl)"
                            subtitle: "Inspect recent user session warnings and errors"
                            onClicked: Quickshell.execDetached(["kitty", "--hold", "--title", "Session errors",
                                "journalctl", "--user", "-b", "-p", "warning", "-n", "80", "--no-pager"])
                        }
                        ToolCard {
                            Layout.fillWidth: true
                            iconName: "software-update-available-symbolic"
                            title: "Check System Updates"
                            subtitle: "List pending Arch Linux package updates"
                            onClicked: Quickshell.execDetached(["kitty", "--hold", "--title", "Check system updates", "sh", "-c",
                                "if command -v checkupdates >/dev/null; then checkupdates; else echo 'Install pacman-contrib to check for updates.'; fi"])
                        }
                        ToolCard {
                            Layout.fillWidth: true
                            iconName: "view-refresh-symbolic"
                            title: "Reload Quickshell"
                            subtitle: "Restart the shell instance if needed"
                            onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exec", "qs -c main"])
                        }
                    }

                    // ================= PAGE 4: ABOUT =================
                    SystemAbout {
                        Layout.fillWidth: true
                        visible: root.safePage === 4
                        fontFamily: root.uiFont
                    }

                    Item { height: 20 }
                }
            }
        }
    }
}
