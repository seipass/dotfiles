import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Menu {
    id: root
    property bool pinned: false
    property bool canPin: true
    property bool canClose: false
    signal toggleRequested()
    signal closeRequested()
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
    MenuItem {
        id: closeItem
        visible: root.canClose
        enabled: root.canClose
        height: visible ? implicitHeight : 0
        implicitHeight: 38
        leftPadding: 14
        text: "終了"
        contentItem: Text {
            text: closeItem.text
            color: LivePalette.color.onSurface
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 12
            color: closeItem.highlighted ? LivePalette.color.surfaceContainerHigh : "transparent"
        }
        onTriggered: root.closeRequested()
    }
}
