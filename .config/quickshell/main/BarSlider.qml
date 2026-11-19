import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Slider {
    id: control
    implicitHeight: 24
    leftPadding: 0
    rightPadding: 0
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 5
        radius: height / 2
        color: LivePalette.color.outlineVariant
        Rectangle {
            width: parent.width * control.visualPosition
            height: parent.height
            radius: height / 2
            color: LivePalette.color.onSurface
            Behavior on width {
                enabled: !control.pressed
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 12
        height: 12
        radius: 6
        color: LivePalette.color.onSurface
        scale: control.pressed ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
    }
}
