import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: root
    required property int percent
    required property bool muted
    required property bool available
    property bool ready: false
    property bool showing: false
    readonly property var monitor: Hyprland.monitorFor(screen)
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
    implicitWidth: 224
    implicitHeight: 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    mask: Region { width: 0; height: 0 }
    WlrLayershell.layer: WlrLayer.Overlay
    Timer { id: hideDelay; interval: 1100; onTriggered: root.showing = false }
    Rectangle {
        id: chip
        anchors.fill: parent
        radius: 20
        color: LivePalette.color.surfaceContainerHigh
        opacity: root.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Text {
            anchors.centerIn: parent
            text: root.muted ? "Volume muted" : "Volume · " + root.percent + "%"
            color: LivePalette.color.onSurface
        }
    }
}
