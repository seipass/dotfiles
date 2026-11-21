import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Menu {
    id: root
    property bool pinned: false
    property bool canPin: true
    property bool canClose: false
    property bool canLaunchNew: false
    signal toggleRequested()
    signal closeRequested()
    signal newWindowRequested()
    popupType: Popup.Window
    padding: 8
    implicitWidth: 224

    // M3 Borderless Elevated Menu Container
    background: Rectangle {
        radius: 20
        color: LivePalette.color.surfaceContainerHigh
    }

    MenuItem {
        id: newWindowItem
        visible: root.canLaunchNew
        enabled: root.canLaunchNew
        height: visible ? implicitHeight : 0
        implicitHeight: visible ? 40 : 0
        leftPadding: 14
        rightPadding: 14
        text: "新しいウィンドウを開く"
        contentItem: RowLayout {
            spacing: 10
            SymbolIcon {
                implicitWidth: 16
                implicitHeight: 16
                iconName: "window-new-symbolic"
                tint: LivePalette.color.primary
            }
            Text {
                Layout.fillWidth: true
                text: newWindowItem.text
                color: LivePalette.color.onSurface
                font.pixelSize: 13
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
        }
        background: Rectangle {
            radius: height / 2
            color: newWindowItem.highlighted ? LivePalette.color.primaryContainer : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        }
        onTriggered: root.newWindowRequested()
    }

    MenuItem {
        id: pinItem
        text: !root.canPin ? "固定不可 (.desktop 未検出)"
            : (root.pinned ? "固定を解除" : "タスクバーに固定")
        enabled: root.canPin
        implicitHeight: 40
        leftPadding: 14
        rightPadding: 14
        contentItem: RowLayout {
            spacing: 10
            SymbolIcon {
                implicitWidth: 16
                implicitHeight: 16
                iconName: root.pinned ? "list-remove-symbolic" : "view-pin-symbolic"
                tint: pinItem.enabled ? LivePalette.color.primary : LivePalette.color.outlineVariant
            }
            Text {
                Layout.fillWidth: true
                text: pinItem.text
                color: pinItem.enabled ? LivePalette.color.onSurface : LivePalette.color.outlineVariant
                font.pixelSize: 13
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
        background: Rectangle {
            radius: height / 2
            color: pinItem.highlighted ? LivePalette.color.primaryContainer : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        }
        onTriggered: root.toggleRequested()
    }

    MenuItem {
        id: closeItem
        visible: root.canClose
        enabled: root.canClose
        height: visible ? implicitHeight : 0
        implicitHeight: visible ? 40 : 0
        leftPadding: 14
        rightPadding: 14
        text: "終了"
        contentItem: RowLayout {
            spacing: 10
            SymbolIcon {
                implicitWidth: 16
                implicitHeight: 16
                iconName: "window-close-symbolic"
                tint: LivePalette.color.error
            }
            Text {
                Layout.fillWidth: true
                text: closeItem.text
                color: LivePalette.color.error
                font.pixelSize: 13
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
        }
        background: Rectangle {
            radius: height / 2
            color: closeItem.highlighted ? LivePalette.color.errorContainer : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        }
        onTriggered: root.closeRequested()
    }
}
