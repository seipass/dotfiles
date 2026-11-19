import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: action
    property bool primary: false
    font.pixelSize: 14
    font.weight: Font.DemiBold
    horizontalPadding: 16
    implicitHeight: 42
    contentItem: Text {
        text: action.text
        font: action.font
        color: action.primary ? LivePalette.color.onPrimary : LivePalette.color.onSurface
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 12
        color: action.primary ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh
        opacity: !action.enabled ? 0.4 : action.down ? 0.78 : action.hovered ? 0.92 : 1
        border.width: action.visualFocus ? 2 : 0
        border.color: action.primary ? LivePalette.color.onPrimary : LivePalette.color.primary
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }
}
