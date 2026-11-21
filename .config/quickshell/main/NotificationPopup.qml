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
    implicitWidth: 400
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
        spacing: 8
        clip: true
        opacity: root.selectingScreen || root.fullscreenActive ? 0 : 1
        enabled: !root.fullscreenActive
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.fast; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard }
            NumberAnimation { property: "x"; from: 28; to: 0; duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion.exit; easing.type: Easing.OutCubic }
            NumberAnimation { property: "x"; to: 42; duration: Theme.motion.exit; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle }
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
            height: closing ? 0 : Math.min(230, bodyColumn.implicitHeight + 32)
            opacity: closing ? 0 : 1
            clip: true
            radius: 24
            color: LivePalette.color.surfaceContainer

            Behavior on height { NumberAnimation { duration: Theme.motion.exit; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.motion.exit; easing.type: Easing.OutCubic } }

            Timer {
                id: closeDelay
                interval: Theme.motion.standard + 20
                onTriggered: {
                    if (card.expired) card.modelData.expire();
                    else card.modelData.dismiss();
                }
            }
            Timer {
                running: card.modelData.expireTimeout !== 0
                interval: card.modelData.expireTimeout > 0 ? Math.max(1000, card.modelData.expireTimeout * 1000) : 6000
                onTriggered: card.closeCard(true)
            }

            ColumnLayout {
                id: bodyColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        radius: 10
                        color: LivePalette.color.primaryContainer
                        implicitWidth: appLabel.implicitWidth + 14
                        implicitHeight: 22

                        Text {
                            id: appLabel
                            anchors.centerIn: parent
                            text: card.modelData.appName || "通知"
                            color: LivePalette.color.primary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // M3 Tonal Close Icon Button
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: closeMouse.pressed ? 8 : 14
                        color: LivePalette.color.surfaceContainerHigh
                        scale: closeMouse.pressed ? 0.88 : (closeMouse.containsMouse ? 1.06 : 1.0)
                        Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                        Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: LivePalette.color.onSurface
                            opacity: closeMouse.pressed ? 0.14 : closeMouse.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                        }
                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 14
                            implicitHeight: 14
                            iconName: "window-close-symbolic"
                            tint: closeMouse.containsMouse ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.closeCard(false)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.modelData.summary
                    textFormat: Text.PlainText
                    color: LivePalette.color.onSurface
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: card.modelData.body
                    textFormat: Text.PlainText
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8
                    visible: card.modelData.actions && card.modelData.actions.length > 0
                    Repeater {
                        model: card.modelData.actions
                        delegate: Rectangle {
                            id: actPill
                            required property var modelData
                            width: actionText.implicitWidth + 26
                            height: 32
                            radius: actMouse.pressed ? 10 : 16
                            color: LivePalette.color.primaryContainer
                            scale: actMouse.pressed ? 0.93 : (actMouse.containsMouse ? 1.03 : 1.0)
                            Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: LivePalette.color.onSurface
                                opacity: actMouse.pressed ? 0.12 : actMouse.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                            }
                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: actPill.modelData.text
                                color: LivePalette.color.onSurface
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: actMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: actPill.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
