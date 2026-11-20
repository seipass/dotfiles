import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    property string detailPage: ""
    property bool capturePending: false
    Timer {
        id: captureDelay
        interval: 270
        onTriggered: {
            root.capturePending = false;
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/hypr/flameshot-screen.py"]);
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
    WlrLayershell.keyboardFocus: opened && detailPage === "Daily Tools" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
                ColumnLayout {
                    id: toolsView
                    anchors.fill: parent
                    spacing: 12
                    opacity: !root.notificationsOpen && !root.detailPage ? 1 : 0
                    visible: opacity > 0
                    y: !root.notificationsOpen ? 0 : 8

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

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
                                 root.closeTools();
                                 captureDelay.restart();
                             }
                        }

                        SettingsActionButton {
                            Layout.fillWidth: true
                            iconName: "network-wireless-symbolic"
                            text: "Network"
                            onClicked: {
                                root.closeTools();
                                Quickshell.execDetached(["nm-connection-editor"]);
                            }
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

                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    id: windowList
                    anchors.fill: parent
                    visible: root.detailPage === "Windows"
                    Repeater {
                        // The live model includes windows from every workspace.
                        model: windowList.visible ? Hyprland.toplevels.values.slice(0, 10) : []
                        delegate: SettingsActionButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: (modelData.title || "Window").slice(0, 42)
                            onClicked: {
                                const raw = modelData.address;
                                const address = raw.startsWith("0x") ? raw : "0x" + raw;
                                Hyprland.dispatch(Hyprland.usingLua
                                    ? "hl.dsp.focus({ window = 'address:" + address + "' })"
                                    : "focuswindow address:" + address);
                                root.closeTools();
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                DailyTools {
                    anchors.fill: parent
                    visible: root.detailPage === "Daily Tools"
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
                        model: root.shellState?.notificationHistory ?? []
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
                                    text: modelData.app
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
                                color: LivePalette.color.onSurface
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                wrapMode: Text.Wrap
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !!text
                                text: modelData.body
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
