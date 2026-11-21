import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Slider {
    id: control
    implicitHeight: 28
    leftPadding: 2
    rightPadding: 2

    background: Item {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 12

        // Inactive Track (M3 Expressive thick rounded track)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: LivePalette.color.surfaceContainerHigh
            border.width: 0
        }

        // Active Track
        Rectangle {
            width: Math.max(height, parent.width * control.visualPosition - 4)
            height: parent.height
            radius: height / 2
            color: control.enabled ? LivePalette.color.primary : LivePalette.color.outlineVariant
            Behavior on width {
                enabled: !control.pressed
                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }
        }
    }

    // M3 Expressive Vertical Pill Handle
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.pressed ? 6 : 4
        height: 24
        radius: width / 2
        color: control.enabled ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
        Behavior on width { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
    }
}
