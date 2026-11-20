import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    required property bool available
    required property var quota
    readonly property var windows: quota.windows ?? []
    readonly property bool stale: windows.length > 0 && windows[0].reset > 0
        && windows[0].reset * 1000 <= clock.date.getTime()
    SystemClock { id: clock; precision: SystemClock.Minutes }
    property bool opened: false
    visible: available
    onAvailableChanged: if (!available) opened = false
    anchors { top: true; right: true }
    margins { top: 4; right: 54 }
    implicitWidth: 224
    implicitHeight: 220
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    focusable: false
    mask: Region {
        item: badge
        Region { item: root.opened ? card : null; width: 0; height: 0 }
    }
    FontLoader { id: uiFont; source: "fonts/GoogleSansFlex.ttf" }

    Rectangle {
        id: badge
        anchors.right: parent.right
        width: 77; height: 32; radius: 12
        color: badgeMouse.containsMouse || root.opened ? LivePalette.color.surfaceContainerHigh : LivePalette.color.surface
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            SymbolIcon { width: 16; height: 16; iconName: "utilities-terminal-symbolic"; tint: LivePalette.color.onSurface }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.windows.length && !root.stale ? Math.round(root.windows[0].used) + "%" : "—"
                font.family: uiFont.name || Qt.application.font.family
                font.pixelSize: 12
                color: LivePalette.color.onSurface
            }
        }
        MouseArea {
            id: badgeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.name: "Codex quota"
            onClicked: root.opened = !root.opened
        }
    }

    Rectangle {
        id: card
        width: parent.width
        y: root.opened ? 40 : 34
        height: details.implicitHeight + 28
        radius: 16
        color: LivePalette.color.surface
        opacity: root.opened ? 1 : 0
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }

        ColumnLayout {
            id: details
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 8
            Text { text: "Codex usage"; font.family: uiFont.name; font.pixelSize: 16; color: LivePalette.color.onSurface }
            Text {
                visible: !root.windows.length
                text: "No local quota snapshot"
                font.family: uiFont.name
                color: LivePalette.color.onSurfaceVariant
            }
            Repeater {
                model: root.windows
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text {
                        text: (modelData.minutes >= 1440 ? modelData.minutes / 1440 + "d" : modelData.minutes ? modelData.minutes / 60 + "h" : "Quota")
                            + "  ·  " + Math.round(modelData.used) + "% used"
                        font.family: uiFont.name
                        color: LivePalette.color.onSurface
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: LivePalette.color.surfaceContainerHigh
                        Rectangle {
                            width: parent.width * modelData.used / 100
                            height: parent.height
                            radius: 2
                            color: LivePalette.color.primary
                        }
                    }
                    Text {
                        visible: modelData.reset > 0
                        text: "Reset · " + Qt.formatDateTime(new Date(modelData.reset * 1000), "MMM d HH:mm")
                        font.family: uiFont.name
                        font.pixelSize: 11
                        color: LivePalette.color.onSurfaceVariant
                    }
                }
            }
            Text {
                visible: !!root.quota.timestamp
                text: visible ? "Last recorded · " + Qt.formatDateTime(new Date(root.quota.timestamp), "MMM d HH:mm") : ""
                font.family: uiFont.name
                font.pixelSize: 11
                color: LivePalette.color.onSurfaceVariant
            }
        }
    }
}
