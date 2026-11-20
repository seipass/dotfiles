import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    property string imagePath: ""
    property bool showClock: false
    property date clockDate: new Date()
    visible: imagePath.length > 0 || showClock
    color: "#191114"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Background
    mask: Region { width: 0; height: 0 }
    Image {
        anchors.fill: parent
        source: root.imagePath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Rectangle {
        visible: root.showClock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.13)
        width: 290
        height: 118
        radius: 28
        color: Qt.alpha(LivePalette.color.surface, 0.85)
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.clockDate, "HH:mm")
                font.pixelSize: 52
                color: LivePalette.color.onSurface
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.clockDate, "dddd, MMMM d")
                font.pixelSize: 15
                color: LivePalette.color.onSurfaceVariant
            }
        }
    }
}
