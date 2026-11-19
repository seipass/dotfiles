import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Menu {
    id: root
    property bool pinned: false
    property bool canPin: true
    signal toggleRequested()
    popupType: Popup.Window
    padding: 6
    implicitWidth: 205

    background: Rectangle {
        radius: 16
        color: LivePalette.color.surfaceContainer
        border.width: 1
        border.color: LivePalette.color.outlineVariant
    }
    MenuItem {
        id: pinItem
        text: root.pinned ? "固定を解除" : "タスクバーに固定"
        enabled: root.canPin
        implicitHeight: 38
        leftPadding: 14
        rightPadding: 14
        contentItem: Text {
            text: pinItem.text
            color: pinItem.enabled ? LivePalette.color.onSurface : LivePalette.color.outlineVariant
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 12
            color: pinItem.highlighted ? LivePalette.color.surfaceContainerHigh : "transparent"
            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        onTriggered: root.toggleRequested()
    }
}
