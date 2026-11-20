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
            radius: 12
            color: alertMouse.containsMouse || alerts.opened ? LivePalette.color.surfaceContainerHigh : LivePalette.color.surface
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            SymbolIcon {
                anchors.centerIn: parent
                iconName: "preferences-system-notifications-symbolic"
                tint: LivePalette.color.onSurface
            }
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 5 }
                width: 7; height: 7; radius: 4
                visible: (root.shellState?.unreadNotifications ?? 0) > 0
                color: LivePalette.color.primary
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
                            radius: 16
                            color: workspaceMouse.containsMouse
                                ? LivePalette.color.surfaceContainerHigh : "transparent"

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.motion.standard
                                    easing.type: Easing.OutCubic
                                }
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
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4 + Math.max(0, workspaceRail.activeId - workspaceRail.pageStart)
                        * (workspaceRail.slotSize + workspaceList.spacing)
                    width: workspaceRail.slotSize
                    height: width
                    radius: width / 2
                    visible: workspaceRail.activeId > 0
                    color: LivePalette.color.primary
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
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
                    visible: root.shellState?.showTaskbar ?? true
                    anchors.fill: parent
                    monitor: root.hyprMonitor
                    controller: root.taskbarController
                    centerY: rail.height / 2 - taskSpace.mapToItem(rail, 0, 0).y
                }
            }

            ColumnLayout {
                id: trayItems
                visible: root.shellState?.showTray ?? true
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: Theme.spacing.small

                Repeater {
                    model: ScriptModel {
                        values: SystemTray.items.values.filter(item => item.status !== Status.Passive)
                    }

                    delegate: Item {
                        id: trayEntry
                        required property var modelData

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22

                        IconImage {
                            anchors.centerIn: parent
                            source: trayEntry.modelData.icon
                            implicitSize: 22
                        }

                        MouseArea {
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
                radius: 20
                color: tools.opened || toolsMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : LivePalette.color.surfaceContainer
                SymbolIcon {
                    anchors.centerIn: parent
                    iconName: "view-more-symbolic"
                    tint: LivePalette.color.onSurface
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
                radius: 20
                color: powerMouse.containsMouse || powerMenu.opened
                    ? LivePalette.color.surfaceContainerHigh : LivePalette.color.surfaceContainer
                border.width: 0

                Behavior on color {
                    ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic }
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
