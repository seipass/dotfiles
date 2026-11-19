import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "Theme.js" as Theme

PanelWindow {
    id: launcherWindow
    property var taskbarController

    property bool launcherOpen: false
    property bool closing: false
    property var filteredEntries: {
        const query = searchInput.text.trim().toLowerCase();
        const entries = DesktopEntries.applications.values.filter(entry => {
            const searchable = [
                entry.name || "",
                entry.genericName || "",
                entry.comment || "",
                (entry.keywords || []).join(" ")
            ].join(" ").toLowerCase();
            return query.length === 0 || searchable.includes(query);
        });
        return entries.sort((left, right) => left.name.localeCompare(right.name));
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: launcherOpen || closing
    focusable: launcherOpen
    color: "transparent"
    mask: Region { item: launcherCard }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: launcherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            launcherWindow.toggleLauncher();
        }
        function isOpen(): bool {
            return launcherWindow.launcherOpen;
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.motion.emphasized + 30
        onTriggered: launcherWindow.closing = false
    }

    function toggleLauncher(): void {
        if (launcherOpen) {
            closeLauncher();
            return;
        }

        closeTimer.stop();
        closing = false;

        for (let i = 0; i < Quickshell.screens.length; ++i) {
            const candidate = Quickshell.screens[i];
            const monitor = Hyprland.monitorFor(candidate);
            if (monitor !== null && monitor.focused) {
                screen = candidate;
                break;
            }
        }

        searchInput.text = "";
        appList.currentIndex = 0;
        launcherOpen = true;
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function closeLauncher(): void {
        launcherOpen = false;
        closing = true;
        closeTimer.restart();
    }

    function launchEntry(entry): void {
        if (entry === null || entry === undefined)
            return;

        closeLauncher();
        entry.execute();
    }

    function launchSelected(): void {
        if (appList.currentIndex >= 0 && appList.currentIndex < appList.count)
            launchEntry(filteredEntries[appList.currentIndex]);
    }

    Rectangle {
        id: launcherCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: launcherWindow.launcherOpen ? parent.height - height : parent.height
        width: Math.min(560, parent.width - 32)
        height: Math.min(540, parent.height)
        radius: Theme.shape.dialogRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: LivePalette.color.surface
        border.width: 0
        enabled: launcherWindow.launcherOpen

        Behavior on y {
            NumberAnimation {
                duration: launcherWindow.launcherOpen ? Theme.motion.emphasized : Theme.motion.exit
                easing.type: launcherWindow.launcherOpen ? Easing.OutQuint : Easing.InOutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: Theme.spacing.medium

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.shape.fullRadius
                color: LivePalette.color.surfaceContainer
                border.width: 0

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    verticalAlignment: TextInput.AlignVCenter
                    color: LivePalette.color.onSurface
                    selectionColor: LivePalette.color.primaryContainer
                    selectedTextColor: LivePalette.color.onSurface
                    font.pixelSize: 15
                    clip: true
                    onTextChanged: {
                        appList.currentIndex = 0;
                        if (launcherWindow.launcherOpen) {
                            resultsFade.stop();
                            appList.opacity = 0.92;
                            resultsFade.start();
                        }
                    }
                    onAccepted: launcherWindow.launchSelected()

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            launcherWindow.closeLauncher();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (appList.count > 0)
                                appList.currentIndex = Math.min(appList.count - 1, appList.currentIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (appList.count > 0)
                                appList.currentIndex = Math.max(0, appList.currentIndex - 1);
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "アプリ名やキーワードで検索"
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 14
                    visible: searchInput.text.length === 0
                    enabled: false
                }
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacing.extraSmall
                model: launcherWindow.filteredEntries
                currentIndex: 0
                NumberAnimation {
                    id: resultsFade
                    target: appList
                    property: "opacity"
                    to: 1
                    duration: Theme.motion.fast
                    easing.type: Easing.OutCubic
                }

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index

                    width: appList.width
                    height: 48
                    radius: Theme.shape.fullRadius
                    color: index === appList.currentIndex
                        ? LivePalette.color.surfaceContainerHigh
                        : appMouse.containsMouse
                            ? LivePalette.color.surfaceContainer : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 11

                        IconImage {
                            source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                            implicitSize: 26
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: appRow.modelData.name
                                color: LivePalette.color.onSurface
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: appRow.modelData.genericName || appRow.modelData.comment || ""
                                color: LivePalette.color.onSurfaceVariant
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    TaskbarMenu {
                        id: appMenu
                        pinned: launcherWindow.taskbarController.isPinned(appRow.modelData.id)
                        onToggleRequested: launcherWindow.taskbarController.togglePin(appRow.modelData.id)
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: appList.currentIndex = appRow.index
                        onClicked: function(event) {
                            if (event.button === Qt.RightButton) appMenu.popup();
                            else launcherWindow.launchEntry(appRow.modelData);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: appList.count === 0
                    text: "該当するアプリがありません"
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 13
                }
            }
            Text {
                Layout.alignment: Qt.AlignRight
                text: "Enter 起動   Esc 閉じる"
                color: LivePalette.color.onSurfaceVariant
                font.pixelSize: 11
            }
        }
    }
}
