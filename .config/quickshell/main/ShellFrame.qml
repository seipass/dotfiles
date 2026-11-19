import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import "Theme.js" as Theme

PanelWindow {
    id: root
    implicitWidth: root.screen ? root.screen.width : 1920
    implicitHeight: root.screen ? root.screen.height : 1080
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    mask: Region { width: 0; height: 0 }
    readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool fullscreenActive: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    visible: !fullscreenActive
    anchors { left: true; right: true; top: true; bottom: true }
    WlrLayershell.layer: WlrLayer.Top

    readonly property real innerRadius: Math.min(Theme.shape.frameInnerRadius, height / 2)
    readonly property real curveFactor: 0.55228475
    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            fillColor: LivePalette.color.surface
            strokeWidth: 0
            startX: Theme.shape.railReservation
            startY: 0
            PathLine { x: Theme.shape.railReservation + root.innerRadius; y: 0 }
            PathCubic {
                control1X: Theme.shape.railReservation + root.innerRadius * (1 - root.curveFactor)
                control1Y: 0
                control2X: Theme.shape.railReservation
                control2Y: root.innerRadius * (1 - root.curveFactor)
                x: Theme.shape.railReservation
                y: root.innerRadius
            }
            PathLine { x: Theme.shape.railReservation; y: root.height - root.innerRadius }
            PathCubic {
                control1X: Theme.shape.railReservation
                control1Y: root.height - root.innerRadius * (1 - root.curveFactor)
                control2X: Theme.shape.railReservation + root.innerRadius * (1 - root.curveFactor)
                control2Y: root.height
                x: Theme.shape.railReservation + root.innerRadius
                y: root.height
            }
            PathLine { x: Theme.shape.railReservation; y: root.height }
            PathLine { x: Theme.shape.railReservation; y: 0 }
        }
    }
}
