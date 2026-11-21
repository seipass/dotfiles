import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Item {
    id: root
    property var monitor
    property var controller
    property real centerY: height / 2

    Flickable {
        id: viewport
        width: parent.width
        height: Math.min(parent.height, items.implicitHeight)
        y: Math.max(0, Math.min(parent.height - height, root.centerY - height / 2))
        contentHeight: items.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: items
            width: viewport.width
            spacing: 4
            add: Transition {
                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Theme.motion.fast; easing.type: Easing.OutCubic }
                NumberAnimation { properties: "scale"; from: 0.88; to: 1; duration: Theme.motion.standard; easing.type: Easing.OutQuint }
            }
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: Theme.motion.standard; easing.type: Easing.OutQuint }
            }
            Repeater {
                model: ScriptModel { values: root.controller ? root.controller.entries : [] }
                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    width: items.width
                    height: 40
                    z: mouse.dragged ? 10 : 0
                    transform: Translate {
                        y: mouse.dragOffset
                        Behavior on y {
                            enabled: !mouse.pressed
                            NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic }
                        }
                    }
                    readonly property bool active: modelData.windows.some(w => w.activated)
                    readonly property var desktop: modelData.desktop

                    // M3 Navigation Rail Active Pill Indicator
                    Rectangle {
                        anchors.centerIn: parent
                        width: 40; height: 40; radius: 20
                        color: entry.active ? LivePalette.color.primaryContainer : "transparent"
                        scale: mouse.pressed ? 0.94 : 1.0
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: LivePalette.color.onSurface
                            opacity: mouse.pressed ? 0.12 : (mouse.containsMouse || mouse.dragged) ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: entry.active ? 14 : entry.modelData.windows.length ? 6 : 0
                        height: 3
                        radius: 2
                        color: entry.active ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                        Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 24
                        source: Quickshell.iconPath(entry.desktop ? entry.desktop.icon : entry.modelData.appId, "application-x-executable")
                    }
                    TaskbarMenu {
                        id: entryMenu
                        pinned: root.controller.isPinned(entry.modelData.id)
                        canPin: !!entry.desktop
                        canClose: entry.modelData.windows.length > 0
                        onCloseRequested: root.controller.closeWindows(entry.modelData)
                        onToggleRequested: root.controller.togglePin(entry.modelData.id)
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        property real pressY: 0
                        property real dragOffset: 0
                        property bool dragged: false
                        onPressed: function(event) {
                            pressY = mapToItem(items, event.x, event.y).y;
                            dragged = false;
                            dragOffset = 0;
                        }
                        onPositionChanged: function(event) {
                            if (pressed && (pressedButtons & Qt.LeftButton)) {
                                const distance = mapToItem(items, event.x, event.y).y - pressY;
                                if (Math.abs(distance) > 8) dragged = true;
                                if (dragged) dragOffset = distance;
                            }
                        }
                        onReleased: function(event) {
                            if (event.button === Qt.LeftButton && dragged) {
                                const y = mapToItem(items, event.x, event.y).y;
                                dragOffset = 0;
                                root.controller.move(entry.index, Math.max(0, Math.min(root.controller.entries.length - 1, Math.floor(y / 44))));
                            }
                        }
                        onCanceled: { dragOffset = 0; dragged = false; }
                        onClicked: function(event) {
                            if (event.button === Qt.RightButton) entryMenu.popup();
                            else if (!dragged) root.controller.activate(entry.modelData);
                        }
                    }
                }
            }
        }
    }
}
