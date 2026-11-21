import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    property var notifications
    property bool selectingScreen: false
    readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool fullscreenActive: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    anchors { top: true; right: true }
    margins { top: Theme.shape.islandReservation; right: 8 }
    implicitWidth: 410
    // Keep the layer surface stable while the notification stack animates.
    implicitHeight: Math.max(1, (root.screen ? root.screen.height : 1080) - Theme.shape.islandReservation)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    mask: root.fullscreenActive ? emptyRegion : contentRegion
    Region { id: emptyRegion; width: 0; height: 0 }
    Region { id: contentRegion; item: content }

    ListView {
        id: content
        x: 0; y: 0; width: parent.width
        height: Math.min(contentHeight, root.implicitHeight)
        implicitHeight: height
        spacing: 0
        clip: true
        opacity: root.selectingScreen || root.fullscreenActive ? 0 : 1
        enabled: !root.fullscreenActive
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.standard; easing.type: Easing.OutCubic }
            NumberAnimation { property: "x"; from: 24; to: 0; duration: Theme.motion.emphasized; easing.type: Easing.OutQuint }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion.fast; easing.type: Easing.InCubic }
            NumberAnimation { property: "x"; to: 45; duration: Theme.motion.fast; easing.type: Easing.InCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.motion.standard; easing.type: Easing.OutQuint }
        }
            model: root.notifications
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                property bool closing: false
                property bool expired: false
                function closeCard(isExpired) {
                    if (closing) return;
                    expired = isExpired;
                    closing = true;
                    closeDelay.start();
                }
                width: content.width
                height: closing ? 0 : Math.min(220, bodyColumn.implicitHeight + 26)
                opacity: closing ? 0 : 1
                clip: true
                Behavior on height { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.motion.exit; easing.type: Easing.OutCubic } }
                Timer {
                    id: closeDelay
                    interval: Theme.motion.standard + 20
                    onTriggered: {
                        if (card.expired) card.modelData.expire();
                        else card.modelData.dismiss();
                    }
                }
                color: LivePalette.color.surfaceContainer
                topLeftRadius: index === 0 ? 22 : 0
                topRightRadius: index === 0 ? 22 : 0
                bottomLeftRadius: index === content.count - 1 ? 22 : 0
                bottomRightRadius: index === content.count - 1 ? 22 : 0
                Rectangle {
                    visible: card.index > 0
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 1
                    color: LivePalette.color.outlineVariant
                }
                Timer {
                    running: card.modelData.expireTimeout !== 0
                    interval: card.modelData.expireTimeout > 0 ? Math.max(1000, card.modelData.expireTimeout * 1000) : 6000
                    onTriggered: card.closeCard(true)
                }
                ColumnLayout {
                    id: bodyColumn
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: card.modelData.appName || "通知"; color: LivePalette.color.primary; font.pixelSize: 11; elide: Text.ElideRight }
                        Text { text: "×"; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 18
                            MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: card.closeCard(false) }
                        }
                    }
                    Text { Layout.fillWidth: true; text: card.modelData.summary; textFormat: Text.PlainText; color: LivePalette.color.onSurface; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: card.modelData.body; textFormat: Text.PlainText; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; visible: text.length > 0 }
                    Flow {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: card.modelData.actions
                            delegate: Rectangle {
                                required property var modelData
                                width: actionText.implicitWidth + 22; height: 28; radius: 14; color: LivePalette.color.surfaceContainerHigh
                                Text { id: actionText; anchors.centerIn: parent; text: parent.modelData.text; color: LivePalette.color.onSurface; font.pixelSize: 11 }
                                MouseArea { anchors.fill: parent; onClicked: parent.modelData.invoke() }
                            }
                        }
                    }
                }
            }
    }
}
