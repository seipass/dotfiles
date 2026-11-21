import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root

    property var launcherController
    property var shellState
    property var taskbarController
    property var panelDate: new Date()
    property int volumePercent: 0
    property bool volumeMuted: false
    property bool volumeAvailable: false

    implicitWidth: Theme.shape.railReservation
    color: LivePalette.color.surface
    focusable: false

    anchors {
        left: true
        top: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Top

    property var hyprMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool fullscreenActive: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    visible: !fullscreenActive
    onFullscreenActiveChanged: if (fullscreenActive) {
        trayMenu.closeMenu(); powerMenu.closeMenu(); alerts.closeTools();
    }
    property bool trayHovered: false

    TrayMenuPopup { id: trayMenu; screen: root.screen }
    PowerMenu { id: powerMenu; screen: root.screen }
    SidebarTools {
        id: tools
        screen: root.screen
        shellState: root.shellState
        launcher: root.launcherController
    }
    SidebarTools {
        id: alerts
        screen: root.screen
        shellState: root.shellState
        alertsOnly: true
    }
    QuotaBadge {
        screen: root.screen
        available: !root.fullscreenActive
        quota: root.shellState?.codexQuota ?? ({})
        preferredProvider: root.shellState?.quotaProvider ?? "auto"
        onRefreshRequested: if (root.shellState) root.shellState.refreshQuota()
    }
    PanelWindow {
        screen: root.screen
        visible: !root.fullscreenActive
        anchors { top: true; right: true }
        margins { top: 4; right: 8 }
        implicitWidth: 40
        implicitHeight: 32
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        focusable: false
        Rectangle {
            anchors.fill: parent
            radius: alertMouse.pressed ? 10 : (alerts.opened ? 11 : height / 2)
            color: alerts.opened ? LivePalette.color.primaryContainer : LivePalette.color.surface
            scale: alertMouse.pressed ? 0.90 : (alertMouse.containsMouse ? 1.04 : 1.0)
            Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: LivePalette.color.onSurface
                opacity: alertMouse.pressed ? 0.12 : alertMouse.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
            }
            SymbolIcon {
                anchors.centerIn: parent
                iconName: "preferences-system-notifications-symbolic"
                tint: alerts.opened ? LivePalette.color.primary : LivePalette.color.onSurface
            }
            Rectangle {
                readonly property bool hasUnread: (root.shellState?.unreadNotifications ?? 0) > 0
                anchors { top: parent.top; right: parent.right; margins: 5 }
                width: 7; height: 7; radius: 4
                scale: hasUnread ? 1.0 : 0.0
                visible: scale > 0.01
                color: LivePalette.color.primary
                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
            }
            MouseArea {
                id: alertMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.name: "Alerts"
                onClicked: alerts.toggle()
            }
        }
    }
    Timer {
        id: trayCloseDelay
        interval: 450
        onTriggered: if (!root.trayHovered && !trayMenu.hovered) trayMenu.closeMenu()
    }
    Connections {
        target: trayMenu
        function onHoveredChanged() {
            if (trayMenu.hovered) trayCloseDelay.stop();
            else trayCloseDelay.restart();
        }
    }

    Item {
        id: rail
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: Theme.shape.railWidth

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: Theme.spacing.small

            // M3 Expressive Morphing Cookie Launcher Button
            Item {
                id: launcherCookieBtn
                readonly property bool isOpen: root.launcherController?.launcherOpen ?? false
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                scale: launcherBtnMouse.pressed ? 0.88 : (launcherBtnMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                MaterialCookie {
                    anchors.fill: parent
                    morph: launcherCookieBtn.isOpen ? 2.0 : (launcherBtnMouse.containsMouse ? 1.0 : 0.0)
                    rotation: launcherCookieBtn.isOpen ? 90 : (launcherBtnMouse.containsMouse ? 40 : 0)
                    fillColor: launcherCookieBtn.isOpen
                        ? LivePalette.color.primary
                        : (launcherBtnMouse.containsMouse
                            ? LivePalette.color.primaryContainer
                            : LivePalette.color.surfaceContainerHigh)
                    Behavior on morph {
                        NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard }
                    }
                    Behavior on rotation {
                        NumberAnimation { duration: Theme.motion.spatialSlow; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle }
                    }
                    Behavior on fillColor { ColorAnimation { duration: Theme.motion.fast } }
                }

                SymbolIcon {
                    anchors.centerIn: parent
                    implicitWidth: 18
                    implicitHeight: 18
                    iconName: "view-app-grid-symbolic"
                    tint: launcherCookieBtn.isOpen ? LivePalette.color.onPrimary : LivePalette.color.primary
                }

                MouseArea {
                    id: launcherBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.name: "App Launcher"
                    onClicked: if (root.launcherController) root.launcherController.toggleLauncher(false)
                }
            }

            Rectangle {
                id: workspaceRail
                readonly property int activeId: root.hyprMonitor?.activeWorkspace?.id ?? 0
                readonly property int pageStart: 1 + Math.floor(Math.max(0, activeId - 1) / 5) * 5
                readonly property int slotSize: 32
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 184
                radius: 20
                color: LivePalette.color.surfaceContainer

                WheelHandler {
                    onWheel: event => {
                        const step = event.angleDelta.y > 0 ? -1 : 1;
                        const nextId = Math.max(1, Math.min(10, workspaceRail.activeId + step));
                        if (nextId !== workspaceRail.activeId) {
                            if (Hyprland.usingLua)
                                Hyprland.dispatch("hl.dsp.focus({ workspace = " + nextId + " })");
                            else
                                Hyprland.dispatch("workspace " + nextId);
                        }
                    }
                }

            ColumnLayout {
                id: workspaceList
                anchors.fill: parent
                anchors.margins: 4
                spacing: Theme.spacing.extraSmall

                Repeater {
                    model: 5

                    delegate: Item {
                        id: workspaceSlot
                        required property int index

                        readonly property int workspaceId: workspaceRail.pageStart + index

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Rectangle {
                            id: workspaceButton
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: workspaceMouse.pressed ? 11 : 16
                            color: workspaceMouse.containsMouse
                                ? LivePalette.color.surfaceContainerHigh : "transparent"
                            scale: workspaceMouse.pressed ? 0.88 : (workspaceMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on radius {
                                NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motion.fast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                 text: "●"
                                 color: LivePalette.color.onSurfaceVariant
                                font.pixelSize: 11
                                 font.weight: Font.Medium
                            }

                            MouseArea {
                                id: workspaceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Hyprland.usingLua) {
                                        Hyprland.dispatch(
                                            "hl.dsp.focus({ workspace = "
                                            + workspaceSlot.workspaceId + " })"
                                        );
                                    } else {
                                        Hyprland.dispatch("workspace " + workspaceSlot.workspaceId);
                                    }
                                }
                            }
                        }
                    }
                }
            }
                // M3 Expressive 2-spring stretch workspace marker
                Rectangle {
                    id: wsMarker
                    readonly property real targetY: 4 + Math.max(0, workspaceRail.activeId - workspaceRail.pageStart)
                        * (workspaceRail.slotSize + workspaceList.spacing)
                    property real headY: targetY
                    property real tailY: targetY

                    Behavior on headY { SpringAnimation { spring: Theme.motion.springLead; damping: Theme.motion.dampingLead } }
                    Behavior on tailY { SpringAnimation { spring: Theme.motion.springTrail; damping: Theme.motion.dampingTrail } }

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.min(headY, tailY)
                    width: workspaceRail.slotSize
                    height: workspaceRail.slotSize + Math.abs(headY - tailY)
                    radius: width / 2
                    visible: workspaceRail.activeId > 0
                    color: LivePalette.color.primary

                    Text {
                        anchors.centerIn: parent
                        text: "◆"
                        color: LivePalette.color.onPrimary
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
            }

            Item {
                id: taskSpace
                Layout.fillHeight: true
                Layout.minimumHeight: 4
                Layout.fillWidth: true

                Taskbar {
                    opacity: (root.shellState?.showTaskbar ?? true) ? 1 : 0
                    visible: opacity > 0
                    anchors.fill: parent
                    anchors.leftMargin: -8
                    anchors.rightMargin: -8
                    screen: root.screen
                    monitor: root.hyprMonitor
                    controller: root.taskbarController
                    currentMonitorOnly: root.shellState?.taskbarCurrentMonitorOnly ?? false
                    centerY: rail.height / 2 - taskSpace.mapToItem(rail, 0, 0).y
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                }
            }

            ColumnLayout {
                id: trayItems
                opacity: (root.shellState?.showTray ?? true) ? 1 : 0
                visible: opacity > 0
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: Theme.spacing.small
                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }

                Repeater {
                    model: ScriptModel {
                        values: SystemTray.items.values.filter(item => item.status !== Status.Passive)
                    }

                    delegate: Item {
                        id: trayEntry
                        required property var modelData

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28

                        Rectangle {
                            anchors.fill: parent
                            radius: trayMouse.pressed ? 8 : 14
                            color: LivePalette.color.surfaceContainerHigh
                            opacity: trayMouse.pressed ? 1.0 : (trayMouse.containsMouse ? 0.9 : 0)
                            scale: trayMouse.pressed ? 0.90 : 1.0
                            Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                            Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            source: trayEntry.modelData.icon
                            implicitSize: 22
                            scale: trayMouse.pressed ? 0.86 : (trayMouse.containsMouse ? 1.10 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.trayHovered = true;
                                trayCloseDelay.stop();
                                if (trayEntry.modelData.hasMenu) {
                                    const pos = mapToItem(root.contentItem, 0, height / 2);
                                    trayMenu.showMenu(trayEntry.modelData.menu, root.screen, pos.y);
                                }
                            }
                            onExited: {
                                root.trayHovered = false;
                                trayCloseDelay.restart();
                            }
                            onClicked: function(event) {
                                const item = trayEntry.modelData;
                                const point = mapToItem(root.contentItem, event.x, event.y);

                                if (event.button === Qt.LeftButton && item.onlyMenu && item.hasMenu) {
                                    trayMenu.showMenu(item.menu, root.screen, point.y);
                                } else if (event.button === Qt.LeftButton) {
                                    item.activate();
                                } else if (event.button === Qt.MiddleButton) {
                                    item.secondaryActivate();
                                } else if (event.button === Qt.RightButton && item.hasMenu) {
                                    trayMenu.showMenu(item.menu, root.screen, point.y);
                                } else if (event.button === Qt.RightButton) {
                                    item.secondaryActivate();
                                }
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: toolsMouse.pressed ? 11 : (tools.opened ? 13 : 20)
                color: tools.opened ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
                scale: toolsMouse.pressed ? 0.90 : (toolsMouse.containsMouse ? 1.05 : 1.0)
                Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
                Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: LivePalette.color.onSurface
                    opacity: toolsMouse.pressed ? 0.12 : toolsMouse.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                }
                SymbolIcon {
                    anchors.centerIn: parent
                    iconName: "view-more-symbolic"
                    tint: tools.opened ? LivePalette.color.primary : LivePalette.color.onSurface
                }
                MouseArea {
                    id: toolsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        trayMenu.closeMenu();
                        powerMenu.closeMenu();
                        tools.opened = !tools.opened;
                    }
                }
            }
            Rectangle {
                id: powerButton
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: powerMouse.pressed ? 11 : (powerMenu.opened ? 13 : 20)
                color: powerMenu.opened ? LivePalette.color.errorContainer : LivePalette.color.surfaceContainer
                scale: powerMouse.pressed ? 0.90 : (powerMouse.containsMouse ? 1.05 : 1.0)
                border.width: 0

                Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
                Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: LivePalette.color.onSurface
                    opacity: powerMouse.pressed ? 0.14 : powerMouse.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                }
                SymbolIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    iconName: "system-shutdown-symbolic"
                    tint: LivePalette.color.error
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { tools.opened = false; trayMenu.closeMenu(); powerMenu.toggle(); }
                }
            }

        }
    }
}
