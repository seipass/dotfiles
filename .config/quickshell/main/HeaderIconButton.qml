import QtQuick
import "Theme.js" as Theme

Rectangle {
    id: hBtn
    property string iconName: ""
    property string label: ""
    signal clicked()

    implicitWidth: 38
    implicitHeight: 38
    radius: hMouse.pressed ? 11 : height / 2
    color: LivePalette.color.surfaceContainerHigh
    scale: hMouse.pressed ? 0.88 : (hMouse.containsMouse ? 1.05 : 1.0)
    Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: LivePalette.color.onSurface
        opacity: hMouse.pressed ? 0.14 : hMouse.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }

    SymbolIcon {
        anchors.centerIn: parent
        implicitWidth: 18
        implicitHeight: 18
        iconName: hBtn.iconName
        tint: hMouse.containsMouse ? LivePalette.color.primary : LivePalette.color.onSurface
    }
    MouseArea {
        id: hMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.name: hBtn.label
        onClicked: hBtn.clicked()
    }
}
