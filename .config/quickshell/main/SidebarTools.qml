import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
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
    property bool notificationsOpen: false
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
    property string detailPage: ""
    property int brightness: -1
    VolumeOsd {
        screen: root.screen
        label: "Brightness"
        percent: Math.max(0, root.brightness)
        muted: false
        available: root.brightness >= 0
    }
    Process {
        id: readBrightness
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/,(\d+)%,/);
                root.brightness = match ? Number(match[1]) : -1;
            }
        }
        onExited: code => { if (code !== 0) root.brightness = -1; }
    }
    Process {
        id: setBrightness
        property string step: ""
        command: ["brightnessctl", "-c", "backlight", "--min-value=1", "set", step]
        onExited: readBrightness.running = true
    }
    property string bluetoothStatus: ""
    property var bluetoothDevices: []
    property string bluetoothError: ""
    Process {
        id: pairedDevices
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: root.bluetoothDevices = text.split("\n").map(line =>
                line.match(/^Device ([0-9a-f:]{17}) (.+)$/i)).filter(Boolean)
        }
    }
    Process {
        id: connectBluetooth
        property string address: ""
        command: ["timeout", "20s", "bluetoothctl", "connect", address]
        onExited: code => root.bluetoothError = code === 0 ? "" : "Could not connect to the selected device."
    }
    property string wifiStatus: ""
    property string wifiError: ""
    property var wifiProfiles: []
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
        onExited: bluetooth.running = true
    }
    onDetailPageChanged: {
        if (detailPage === "Brightness") readBrightness.running = true;
        if (detailPage === "Bluetooth") {
            bluetooth.running = true;
            pairedDevices.running = true;
        }
        if (detailPage === "Network") {
            wifiScan.running = true;
            savedWifi.running = true;
        }
    }
    property bool capturePending: false
    property bool captureWithoutEditor: false
    property bool captureText: false
    property bool translateText: false
    property bool imageSearch: false
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
    onOpenedChanged: if (opened) detailPage = ""

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

    onVisibleChanged: if (!visible) { notificationsOpen = false; }

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
    mask: null

    // Click outside to dismiss (not a modal blocker: only captures outside click to dismiss)
    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeTools()
    }

    Timer {
        id: closeTimer
        interval: 220
        onTriggered: root.closing = false
    }

    Rectangle {
        id: panel
        readonly property real targetX: Theme.shape.railWidth + 8
        readonly property real targetY: Math.max(12, parent.height - height - 12)

        x: root.opened ? targetX : (targetX - 28)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: 380
        height: Math.min(560, (root.screen?.height ?? 600) - 40)
        radius: 20
        color: LivePalette.color.surfaceContainer
        border.color: Qt.alpha(LivePalette.color.onSurface, 0.08)
        border.width: 1
        clip: true
        Dialog {
            id: translationConsent
            anchors.centerIn: parent
            width: parent.width - 24
            modal: true
            title: "Translate Screen Text"
            standardButtons: Dialog.Ok | Dialog.Cancel
            contentItem: Label {
                text: "The text recognized in the area you select will be sent to Google Translate. The screenshot is not uploaded."
                wrapMode: Text.Wrap
            }
            onAccepted: {
                root.capturePending = true;
                root.captureWithoutEditor = true;
                root.captureText = true;
                root.translateText = true;
                root.closeTools();
                captureDelay.restart();
            }
        }

        // Catch clicks inside panel so they don't trigger outside dismiss
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        // Smooth horizontal slide from left rail + fade
        opacity: root.opened ? 1 : 0

        Behavior on x {
            NumberAnimation {
                duration: root.opened ? 260 : 180
                easing.type: root.opened ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.opened ? 220 : 160
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Header Section (Clean typography, no left logo, no close button)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    id: headerTitle
                    text: root.detailPage || (root.notificationsOpen ? "Notifications" : "Quick Tools")
                    color: LivePalette.color.onSurface
                    font.pixelSize: 18
                    font.weight: Font.DemiBold

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Text {
                    text: root.notificationsOpen ? "Recent activity and alerts" : "Quick actions & system settings"
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 12
                }
            }

            // Notification / Quick Tools Sliding Pill Tab
            Rectangle {
                id: tabContainer
                Layout.fillWidth: true
                height: 40
                radius: 10
                color: LivePalette.color.surface
                border.color: Qt.alpha(LivePalette.color.onSurface, 0.06)
                border.width: 1

                readonly property real tabWidth: (width - 6) / 2

                // Smooth Sliding Active Pill
                Rectangle {
                    x: 3 + (root.notificationsOpen ? tabContainer.tabWidth : 0)
                    y: 3
                    width: tabContainer.tabWidth
                    height: tabContainer.height - 6
                    radius: 8
                    color: Qt.alpha(LivePalette.color.primary, 0.18)
                    border.color: Qt.alpha(LivePalette.color.primary, 0.32)
                    border.width: 1

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 3

                    Item {
                        width: tabContainer.tabWidth
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: "Tools"
                            font.pixelSize: 13
                            font.weight: !root.notificationsOpen ? Font.DemiBold : Font.Normal
                            color: !root.notificationsOpen ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant

                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.detailPage = ""; root.notificationsOpen = false; }
                        }
                    }

                    Item {
                        width: tabContainer.tabWidth
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: "Alerts" + ((root.shellState?.unreadNotifications ?? 0) ? " (" + root.shellState.unreadNotifications + ")" : "")
                            font.pixelSize: 13
                            font.weight: root.notificationsOpen ? Font.DemiBold : Font.Normal
                            color: root.notificationsOpen ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant

                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.detailPage = "";
                                root.notificationsOpen = true;
                                if (root.shellState) root.shellState.unreadNotifications = 0;
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(LivePalette.color.onSurface, 0.05) }

            // Content Container with smooth fade between views
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ================= VIEW: QUICK TOOLS =================
                ScrollView {
                    anchors.fill: parent
                    opacity: !root.notificationsOpen && !root.detailPage ? 1 : 0
                    visible: opacity > 0
                    enabled: !root.notificationsOpen && !root.detailPage
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        width: parent.width
                        spacing: 12

                    // Quick Launch Grid (4 Action Buttons)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Daily Tools"
                            onClicked: root.detailPage = "Daily Tools"
                        }

                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Windows"
                            onClicked: root.detailPage = "Windows"
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Wallpapers"
                            onClicked: root.detailPage = "Wallpapers"
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Bluetooth"
                            onClicked: root.detailPage = "Bluetooth"
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Bar Appearance"
                            onClicked: root.detailPage = "Bar Appearance"
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Brightness"
                            onClicked: root.detailPage = "Brightness"
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Clipboard"
                            onClicked: root.detailPage = "Clipboard"
                        }

                        SettingsActionButton {
                            Layout.fillWidth: true
                            iconName: "system-search-symbolic"
                            text: "App Launcher"
                            onClicked: {
                                root.closeTools();
                                root.launcher.toggleLauncher(false);
                            }
                        }

                        SettingsActionButton {
                            Layout.fillWidth: true
                            iconName: "camera-photo-symbolic"
                             text: "Screenshot"
                             enabled: !root.capturePending
                             onClicked: {
                                 root.capturePending = true;
                                 root.captureWithoutEditor = false;
                                 root.captureText = false;
                                 root.closeTools();
                                 captureDelay.restart();
                             }
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                            text: "Save Region"
                            enabled: !root.capturePending
                            onClicked: {
                                root.capturePending = true;
                                root.captureWithoutEditor = true;
                                root.captureText = false;
                                root.closeTools();
                                captureDelay.restart();
                            }
                        }
                        SettingsActionButton {
                            Layout.fillWidth: true
                             text: "Read Screen Text"
                            enabled: !root.capturePending
                            onClicked: {
                                root.capturePending = true;
                                root.captureWithoutEditor = true;
                                 root.captureText = true;
                                 root.translateText = false;
                                root.closeTools();
                                captureDelay.restart();
                         }
                         SettingsActionButton {
                             Layout.fillWidth: true
                             text: "Translate Screen Text"
                             enabled: !root.capturePending
                             onClicked: translationConsent.open()
                         }
                         SettingsActionButton {
                             Layout.fillWidth: true
                             text: "Capture for Image Search"
                             enabled: !root.capturePending
                             onClicked: {
                                 root.capturePending = true;
                                 root.captureWithoutEditor = true;
                                 root.captureText = false;
                                 root.imageSearch = true;
                                 root.closeTools();
                                 captureDelay.restart();
                             }
                         }
                        }

                        SettingsActionButton {
                            Layout.fillWidth: true
                            iconName: "network-wireless-symbolic"
                             text: "Network"
                             onClicked: root.detailPage = "Network"
                        }

                        SettingsActionButton {
                            Layout.fillWidth: true
                            iconName: "preferences-system-symbolic"
                            text: "Settings"
                            onClicked: {
                                root.closeTools();
                                root.shellState.openSettings(root.screen);
                            }
                        }
                    }

                    // Volume Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: LivePalette.color.surface
                        border.color: Qt.alpha(LivePalette.color.onSurface, 0.06)
                        border.width: 1
                        implicitHeight: volCol.implicitHeight + 20

                        ColumnLayout {
                            id: volCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SymbolIcon {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    iconName: root.shellState?.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                                    tint: LivePalette.color.primary

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                    }
                                }

                                Text {
                                    text: "Master Volume"
                                    color: LivePalette.color.onSurface
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.shellState?.volumeMuted ? "Muted" : (root.shellState?.volumePercent ?? 0) + "%"
                                    color: LivePalette.color.onSurfaceVariant
                                    font.pixelSize: 12
                                }
                            }

                            BarSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: root.shellState?.volumePercent ?? 0
                                enabled: root.shellState?.volumeAvailable ?? false
                                onMoved: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)])
                            }
                        }
                    }

                    // Desktop Clock Toggle Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: LivePalette.color.surface
                        border.color: Qt.alpha(LivePalette.color.onSurface, 0.06)
                        border.width: 1
                        implicitHeight: 46

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: clockToggleMouse.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.04) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    Layout.fillWidth: true
                                    text: "Desktop Clock Widget"
                                    color: LivePalette.color.onSurface
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: (root.shellState?.desktopClock ?? false) ? LivePalette.color.primary : Qt.alpha(LivePalette.color.outlineVariant, 0.5)
                                    border.width: 1.5
                                    border.color: (root.shellState?.desktopClock ?? false) ? LivePalette.color.primary : LivePalette.color.outlineVariant

                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Behavior on border.color { ColorAnimation { duration: 180 } }

                                    Rectangle {
                                        x: (root.shellState?.desktopClock ?? false) ? parent.width - width - 3 : 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (root.shellState?.desktopClock ?? false) ? 18 : 14
                                        height: width
                                        radius: width / 2
                                        color: (root.shellState?.desktopClock ?? false) ? LivePalette.color.onPrimary : LivePalette.color.onSurfaceVariant

                                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: clockToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.shellState) {
                                        root.shellState.setDesktopClock(!root.shellState.desktopClock);
                                    }
                                }
                            }
                        }
                    }

                    }
                }

                ColumnLayout {
                    id: windowList
                    anchors.fill: parent
                    visible: root.detailPage === "Windows"
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: windowList.visible ? Hyprland.workspaces.values.filter(ws => ws.id > 0) : []
                            delegate: SettingsActionButton {
                                required property var modelData
                                text: String(modelData.id)
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
                        cellHeight: 112
                        model: windowList.visible ? Hyprland.toplevels.values : []
                        delegate: Button {
                            required property var modelData
                            id: windowTile
                            width: windowGrid.cellWidth - 5
                            height: windowGrid.cellHeight - 5
                            text: modelData.title || "Window"
                            contentItem: ColumnLayout {
                                ScreencopyView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    captureSource: windowTile.modelData.wayland
                                    live: false
                                    paintCursor: false
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: windowTile.text
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                }
                            }
                            onClicked: {
                                const raw = modelData.address;
                                const address = raw.startsWith("0x") ? raw : "0x" + raw;
                                Hyprland.dispatch(Hyprland.usingLua
                                    ? "hl.dsp.focus({ window = 'address:" + address + "' })"
                                    : "focuswindow address:" + address);
                                root.closeTools();
                            }
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                }
                DailyTools {
                    anchors.fill: parent
                    visible: root.detailPage === "Daily Tools"
                }
                ClipboardTools {
                    anchors.fill: parent
                    visible: root.opened && root.detailPage === "Clipboard"
                }
                WallpaperBrowser {
                    anchors.fill: parent
                    visible: root.detailPage === "Wallpapers"
                    selected: root.shellState?.wallpaperPath ?? ""
                    onChosen: path => root.shellState.setWallpaper(path)
                }
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.detailPage === "Brightness"
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: readBrightness.running ? "Checking backlight…" : root.brightness < 0
                            ? "No supported backlight. This control requires brightnessctl and a backlight device."
                            : "Brightness · " + root.brightness + "%"
                        color: LivePalette.color.onSurface
                    }
                    RowLayout {
                        enabled: root.brightness >= 0 && !setBrightness.running && !readBrightness.running
                        SettingsActionButton {
                            text: "− 5%"
                            onClicked: { setBrightness.step = "5%-"; setBrightness.running = true; }
                        }
                        SettingsActionButton {
                            text: "+ 5%"
                            onClicked: { setBrightness.step = "+5%"; setBrightness.running = true; }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.detailPage === "Bar Appearance"
                    Switch {
                        text: "Show Taskbar"
                        checked: root.shellState?.showTaskbar ?? true
                        onToggled: root.shellState.showTaskbar = checked
                    }
                    Switch {
                        text: "Show System Tray"
                        checked: root.shellState?.showTray ?? true
                        onToggled: root.shellState.showTray = checked
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.detailPage === "Network"
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: newSsid
                            Layout.fillWidth: true
                            placeholderText: "New network name (SSID)"
                            Accessible.name: "New network name"
                        }
                        SettingsActionButton {
                            text: "Join"
                            enabled: newSsid.text.length > 0 && !newSsid.text.startsWith("-") && !connectWifi.running
                            onClicked: {
                                root.closeTools();
                                Quickshell.execDetached(["kitty", "--hold", "--title", "Join Wi-Fi",
                                    "nmcli", "--ask", "device", "wifi", "connect", newSsid.text]);
                            }
                        }
                    }
                    ComboBox {
                        id: profile
                        Layout.fillWidth: true
                        model: root.wifiProfiles.map(item => item[2])
                        displayText: count ? currentText : "No saved Wi-Fi profiles"
                    }
                    SettingsActionButton {
                        text: connectWifi.running ? "Connecting…" : "Connect to Saved Network"
                        enabled: profile.currentIndex >= 0 && !connectWifi.running
                        onClicked: {
                            root.wifiError = "";
                            connectWifi.uuid = root.wifiProfiles[profile.currentIndex][1];
                            connectWifi.running = true;
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: !!root.wifiError
                        text: root.wifiError
                        wrapMode: Text.Wrap
                        color: LivePalette.color.error
                    }
                    RowLayout {
                        SettingsActionButton {
                            text: "Refresh Wi-Fi"
                            enabled: !wifiScan.running
                            onClicked: wifiScan.running = true
                        }
                        SettingsActionButton {
                            text: "Connections"
                            onClicked: {
                                root.closeTools();
                                Quickshell.execDetached(["nm-connection-editor"]);
                            }
                        }
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Label {
                            text: wifiScan.running ? "Checking Wi-Fi…" : root.wifiStatus || "No Wi-Fi networks found."
                            textFormat: Text.PlainText
                            color: LivePalette.color.onSurface
                        }
                    }
                }
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.detailPage === "Bluetooth"
                    Label {
                        text: bluetooth.running ? "Checking Bluetooth…"
                            : !root.bluetoothStatus ? "No controller found"
                            : /Powered:\s+yes/.test(root.bluetoothStatus) ? "Bluetooth is on" : "Bluetooth is off"
                        color: LivePalette.color.onSurface
                    }
                    SettingsActionButton {
                        text: "Refresh"
                        enabled: !bluetooth.running
                        onClicked: { bluetooth.running = true; pairedDevices.running = true; }
                    }
                    ComboBox {
                        id: pairedDevice
                        Layout.fillWidth: true
                        model: root.bluetoothDevices.map(item => item[2])
                        displayText: count ? currentText : "No paired devices"
                    }
                    SettingsActionButton {
                        text: connectBluetooth.running ? "Connecting…" : "Connect Paired Device"
                        enabled: pairedDevice.currentIndex >= 0 && !connectBluetooth.running
                        onClicked: {
                            root.bluetoothError = "";
                            connectBluetooth.address = root.bluetoothDevices[pairedDevice.currentIndex][1];
                            connectBluetooth.running = true;
                        }
                    }
                    SettingsActionButton {
                        text: "Pair New Device in Terminal"
                        onClicked: {
                            root.closeTools();
                            Quickshell.execDetached(["kitty", "--title", "Bluetooth pairing",
                                "bluetoothctl", "--agent", "KeyboardDisplay"]);
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "In the terminal: run scan on, then pair followed by the device address. Follow the pairing prompts."
                        color: LivePalette.color.onSurfaceVariant
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: !!root.bluetoothError
                        text: root.bluetoothError
                        wrapMode: Text.Wrap
                        color: LivePalette.color.error
                    }
                    SettingsActionButton {
                        readonly property bool powered: /Powered:\s+yes/.test(root.bluetoothStatus)
                        text: powered ? "Turn Bluetooth Off" : "Turn Bluetooth On"
                        enabled: !!root.bluetoothStatus && !bluetooth.running && !bluetoothPower.running
                        onClicked: {
                            bluetoothPower.enable = !powered;
                            bluetoothPower.running = true;
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                // ================= VIEW: NOTIFICATIONS =================
                ColumnLayout {
                    id: alertsView
                    anchors.fill: parent
                    spacing: 10
                    opacity: root.notificationsOpen ? 1 : 0
                    visible: opacity > 0
                    y: root.notificationsOpen ? 0 : 8

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    // DND Toggle Card
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 12
                        color: LivePalette.color.surface
                        border.color: Qt.alpha(LivePalette.color.onSurface, 0.06)
                        border.width: 1
                        implicitHeight: 46

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: dndToggleMouse.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.04) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    Layout.fillWidth: true
                                    text: "Do Not Disturb"
                                    color: LivePalette.color.onSurface
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Rectangle {
                                    width: 44
                                    height: 24
                                    radius: 12
                                    color: (root.shellState?.doNotDisturb ?? false) ? LivePalette.color.primary : Qt.alpha(LivePalette.color.outlineVariant, 0.5)
                                    border.width: 1.5
                                    border.color: (root.shellState?.doNotDisturb ?? false) ? LivePalette.color.primary : LivePalette.color.outlineVariant

                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Behavior on border.color { ColorAnimation { duration: 180 } }

                                    Rectangle {
                                        x: (root.shellState?.doNotDisturb ?? false) ? parent.width - width - 3 : 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (root.shellState?.doNotDisturb ?? false) ? 18 : 14
                                        height: width
                                        radius: width / 2
                                        color: (root.shellState?.doNotDisturb ?? false) ? LivePalette.color.onPrimary : LivePalette.color.onSurfaceVariant

                                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: dndToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.shellState) {
                                        root.shellState.doNotDisturb = !root.shellState.doNotDisturb;
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Recent Notifications"
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        SettingsActionButton {
                            visible: history.count > 0
                            text: "Clear All"
                            onClicked: {
                                if (root.shellState) {
                                    root.shellState.notificationHistory = [];
                                    root.shellState.unreadNotifications = 0;
                                }
                            }
                        }
                    }

                    // Empty State
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
                                text: "No notifications yet"
                                color: LivePalette.color.onSurfaceVariant
                                font.pixelSize: 12
                            }
                        }
                    }

                    // Notifications List
                    ListView {
                        id: history
                        visible: count > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                         model: root.groupNotifications(root.shellState?.notificationHistory ?? [])
                        ScrollBar.vertical: ScrollBar { active: true }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: history.width - 8
                            implicitHeight: notifCol.implicitHeight + 20
                            radius: 12
                            color: LivePalette.color.surface
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.06)
                            border.width: 1

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
                                    font.pixelSize: 10
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
                                font.pixelSize: 11
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
