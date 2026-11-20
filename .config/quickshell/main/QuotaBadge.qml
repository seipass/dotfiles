import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Theme.js" as Theme

PanelWindow {
    id: root
    required property bool available
    required property var quota
    readonly property var windows: quota.windows ?? []
    SystemClock { id: clock; precision: SystemClock.Minutes }
    property bool opened: false
    visible: available
    onAvailableChanged: if (!available) opened = false
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    focusable: false
    mask: root.opened ? null : badgeInput
    Region { id: badgeInput; item: badge }
    FontLoader { id: uiFont; source: "fonts/GoogleSansFlex.ttf" }

    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.opened = false
    }
    Rectangle {
        id: badge
        anchors.right: parent.right
        anchors.rightMargin: 54
        y: 4
        width: 77; height: 32; radius: 12
        color: badgeMouse.containsMouse || root.opened ? LivePalette.color.surfaceContainerHigh : LivePalette.color.surface
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Image {
                id: codexIcon
                width: 16
                height: 16
                // The monochrome provider mark is from YapCap (MPL-2.0).
                source: Qt.resolvedUrl("codex-badge.svg")
                sourceSize: Qt.size(32, 32)
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: LivePalette.color.onSurface
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [300, 10080]
                    delegate: Rectangle {
                        id: track
                        required property int modelData
                        readonly property var window: root.windows.find(item => Number(item.minutes) === modelData)
                        readonly property bool known: !!window && !(window.reset > 0 && window.reset * 1000 <= clock.date.getTime())
                        width: 34
                        height: 4
                        radius: 2
                        color: known ? LivePalette.color.surfaceContainerHigh : "transparent"
                        border.width: known ? 0 : 1
                        border.color: LivePalette.color.onSurfaceVariant
                        Rectangle {
                            width: track.known ? track.width * track.window.used / 100 : 0
                            height: track.height
                            radius: 2
                            color: LivePalette.color.primary
                            Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
        MouseArea {
            id: badgeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.name: "Codex usage: 5-hour limit above, weekly limit below"
            onClicked: root.opened = !root.opened
        }
    }

    Rectangle {
        id: card
        anchors.right: badge.right
        width: 224
        y: root.opened ? 44 : 38
        height: details.implicitHeight + 28
        radius: 16
        color: LivePalette.color.surface
        opacity: root.opened ? 1 : 0
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        ColumnLayout {
            id: details
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 8
            Text { text: "Codex usage"; font.family: "Ndot 55"; font.pixelSize: 16; color: LivePalette.color.onSurface }
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
                text: visible ? (root.quota.live ? "Updated · " : "Local record · ")
                    + Qt.formatDateTime(new Date(root.quota.timestamp), "MMM d HH:mm") : ""
                font.family: uiFont.name
                font.pixelSize: 11
                color: LivePalette.color.onSurfaceVariant
            }
        }
    }
}
