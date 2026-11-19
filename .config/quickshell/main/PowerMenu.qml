import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    property bool opened: false
    property bool closing: false
    function toggle() {
        if (opened) closeMenu();
        else { closeTimer.stop(); closing = false; opened = true; }
    }
    function closeMenu() {
        if (!opened) return;
        opened = false;
        closing = true;
        closeTimer.restart();
    }
    visible: opened || closing
    implicitWidth: 330
    implicitHeight: 60
    margins.left: Theme.shape.railWidth
    margins.bottom: 10
    anchors { left: true; bottom: true }
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: panel }

    Timer { id: closeTimer; interval: Theme.motion.exit; onTriggered: root.closing = false }
    Rectangle {
        id: panel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.opened ? 324 : 300
        height: 48
        radius: 22
        color: LivePalette.color.surfaceContainer
        opacity: root.opened ? 1 : 0
        Behavior on width { NumberAnimation { duration: Theme.motion.exit; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2
            Repeater {
                model: [
                    { label: "シャットダウン", icon: "system-shutdown-symbolic", available: true },
                    { label: "スリープ", icon: "weather-clear-night-symbolic", available: false },
                    { label: "ロック", icon: "system-lock-screen-symbolic", available: false }
                ]
                delegate: Rectangle {
                    id: action
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 18
                    color: actionMouse.containsMouse && modelData.available ? LivePalette.color.surfaceContainerHigh : "transparent"
                    opacity: modelData.available ? 1 : 0.4
                    Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        SymbolIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: action.modelData.icon
                            tint: action.modelData.available ? LivePalette.color.error : LivePalette.color.onSurfaceVariant
                            width: 16; height: 16
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: action.modelData.label
                            font.pixelSize: 11
                            color: LivePalette.color.onSurface
                        }
                    }
                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        enabled: action.modelData.available && root.opened
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeMenu();
                            Quickshell.execDetached(["systemctl", "poweroff"]);
                        }
                    }
                }
            }
        }
    }
}
