import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    required property int percent
    required property bool muted
    required property bool available
    property string label: "Volume"
    property bool ready: false
    property bool showing: false
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property string iconName: {
        if (label === "Brightness") return "display-brightness-symbolic";
        if (muted || percent <= 0) return "audio-volume-muted-symbolic";
        if (percent < 35) return "audio-volume-low-symbolic";
        if (percent < 70) return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }
    function flash() {
        if (!ready || !available || !monitor?.focused || monitor?.activeWorkspace?.hasFullscreen) return;
        showing = true;
        hideDelay.restart();
    }
    Component.onCompleted: ready = true
    onPercentChanged: flash()
    onMutedChanged: flash()
    visible: showing || chip.opacity > 0
    anchors.bottom: true
    margins.bottom: 24
    implicitWidth: 268
    implicitHeight: 80
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    mask: Region { width: 0; height: 0 }
    WlrLayershell.layer: WlrLayer.Overlay
    Timer { id: hideDelay; interval: 1200; onTriggered: root.showing = false }

    Rectangle {
        id: chip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 58
        radius: height / 2
        color: LivePalette.color.surfaceContainerHigh
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.88
        transformOrigin: Item.Bottom
        transform: Translate {
            y: root.showing ? 0 : 16
            Behavior on y {
                NumberAnimation {
                    duration: root.showing ? Theme.motion.spatial : Theme.motion.exit
                    easing.type: root.showing ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: root.showing ? Theme.motion.overshootStandard : 0
                }
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale {
            NumberAnimation {
                duration: root.showing ? Theme.motion.spatial : Theme.motion.exit
                easing.type: root.showing ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: root.showing ? Theme.motion.overshootStandard : 0
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 18
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: root.muted ? 11 : 18
                color: root.muted ? LivePalette.color.surfaceContainer : LivePalette.color.primaryContainer
                Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                SymbolIcon {
                    anchors.centerIn: parent
                    implicitWidth: 18
                    implicitHeight: 18
                    iconName: root.iconName
                    tint: root.muted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.label
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: LivePalette.color.onSurface
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.muted ? "Muted" : root.percent + "%"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: root.muted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    clip: true
                    color: LivePalette.color.surfaceContainer

                    Rectangle {
                        width: root.muted ? 0 : parent.width * Math.max(0, Math.min(100, root.percent)) / 100
                        height: parent.height
                        radius: 4
                        color: LivePalette.color.primary
                        Behavior on width { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle } }
                    }
                }
            }
        }
    }
}
