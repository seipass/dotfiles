import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    property string imagePath: ""
    visible: imagePath.length > 0
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
}
