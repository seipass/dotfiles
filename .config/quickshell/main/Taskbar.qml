import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Item {
    id: root
    property var screen: null
    property var monitor: null
    property var controller: null
    property bool currentMonitorOnly: false
    property real centerY: height / 2

    readonly property int slotHeight: 40
    readonly property int slotSpacing: 4
    readonly property int slotStep: slotHeight + slotSpacing

    readonly property var entryList: root.controller
        ? root.controller.entriesForMonitor(root.monitor, root.currentMonitorOnly)
        : []
    readonly property var entryIds: entryList.map(e => e.id)

    property int draggingIndex: -1
    property int dropIndex: -1
    property real dragDeltaY: 0
    property int autoScrollDir: 0
    property string hoveredId: ""
    property real hoveredY: 0

    function itemCenterInScreen(item) {
        return item.mapToItem(null, 0, item.height / 2).y;
    }

    function clearDragState() {
        draggingIndex = -1;
        dropIndex = -1;
        dragDeltaY = 0;
        autoScrollDir = 0;
    }

    TaskbarOverlay {
        id: overlay
        screen: root.screen
        controller: root.controller
        monitor: root.monitor
        currentMonitorOnly: root.currentMonitorOnly
    }

    Timer {
        id: tooltipDelay
        interval: overlay.shown ? 0 : 180
        onTriggered: {
            if (root.draggingIndex < 0 && root.hoveredId && !overlay.menuOpen) {
                overlay.showTooltip(root.hoveredId, root.hoveredY);
            }
        }
    }

    Timer {
        id: autoScrollTimer
        interval: 16
        repeat: true
        running: root.draggingIndex >= 0 && root.autoScrollDir !== 0
        onTriggered: {
            const maxY = Math.max(0, viewport.contentHeight - viewport.height);
            const prevY = viewport.contentY;
            const nextY = Math.max(0, Math.min(maxY, prevY + root.autoScrollDir * 5));
            const applied = nextY - prevY;
            if (Math.abs(applied) > 0.01) {
                viewport.contentY = nextY;
                root.dragDeltaY += applied;
                const rawTarget = root.draggingIndex + Math.round(root.dragDeltaY / root.slotStep);
                root.dropIndex = Math.max(0, Math.min(root.entryIds.length - 1, rawTarget));
            }
        }
    }

    Flickable {
        id: viewport
        width: parent.width
        height: Math.min(parent.height, items.implicitHeight)
        y: Math.max(0, Math.min(parent.height - height, root.centerY - height / 2))
        contentHeight: items.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.draggingIndex < 0
        clip: true

        Column {
            id: items
            width: viewport.width
            spacing: root.slotSpacing
            add: Transition {
                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Theme.motion.fast; easing.type: Easing.OutCubic }
                NumberAnimation { properties: "scale"; from: 0.85; to: 1; duration: Theme.motion.standard; easing.type: Easing.OutBack }
            }
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: Theme.motion.standard; easing.type: Easing.OutQuint }
            }

            Repeater {
                model: ScriptModel { values: root.entryIds }

                delegate: Item {
                    id: entry
                    required property string modelData
                    required property int index

                    readonly property var appItem: root.controller
                        ? root.controller.findEntry(modelData, root.monitor, root.currentMonitorOnly)
                        : null
                    readonly property var windows: appItem ? appItem.windows : []
                    readonly property int winCount: windows.length
                    readonly property bool active: windows.some(w => w.activated)
                    readonly property bool onCurrentMonitor: !!(root.monitor && windows.some(w => w.monitor?.name === root.monitor.name))
                    readonly property bool isDragging: root.draggingIndex === index
                    readonly property real siblingShift: {
                        if (root.draggingIndex < 0 || root.dropIndex < 0 || isDragging) return 0;
                        if (root.draggingIndex < root.dropIndex && index > root.draggingIndex && index <= root.dropIndex)
                            return -root.slotStep;
                        if (root.draggingIndex > root.dropIndex && index >= root.dropIndex && index < root.draggingIndex)
                            return root.slotStep;
                        return 0;
                    }

                    width: items.width
                    height: root.slotHeight
                    z: isDragging ? 20 : 0

                    transform: Translate {
                        y: entry.isDragging ? root.dragDeltaY : entry.siblingShift
                        Behavior on y {
                            enabled: !entry.isDragging
                            NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic }
                        }
                    }

                    // M3 Left-edge vertical running & multi-window indicator
                    Column {
                        id: indicatorStack
                        anchors.verticalCenter: parent.verticalCenter
                        x: 2
                        spacing: 2
                        visible: entry.winCount > 0

                        Repeater {
                            model: entry.winCount === 0 ? 0 : (entry.active ? Math.min(2, entry.winCount) : Math.min(3, entry.winCount))
                            delegate: Rectangle {
                                required property int index
                                readonly property bool isMain: index === 0
                                width: entry.active && isMain ? 4 : 3.5
                                height: entry.active
                                    ? (isMain ? (entry.winCount > 1 ? 14 : 18) : 4)
                                    : (entry.winCount > 1 ? 5 : 8)
                                radius: width / 2
                                color: entry.active
                                    ? (isMain ? LivePalette.color.primary : Qt.alpha(LivePalette.color.primary, 0.75))
                                    : (entry.onCurrentMonitor
                                        ? LivePalette.color.primary
                                        : Qt.alpha(LivePalette.color.primary, 0.7))

                                Behavior on height { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    // M3 Expressive Morphing Icon Container (20 unlaunched/running -> 15 hover -> 13 active)
                    Rectangle {
                        id: bgPill
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        readonly property color activeContainerColor: LivePalette.color.surface.hslLightness < 0.5
                            ? Qt.tint(LivePalette.color.primaryContainer, Qt.alpha(LivePalette.color.primary, 0.40))
                            : LivePalette.color.primaryContainer
                        radius: entry.active ? 13 : ((mouse.containsMouse || entry.isDragging) ? 15 : 20)
                        color: entry.active
                            ? activeContainerColor
                            : ((mouse.containsMouse || entry.isDragging)
                                ? LivePalette.color.surfaceContainerHigh
                                : "transparent")
                        scale: entry.isDragging ? 1.07
                            : (mouse.pressed || middleBounce.running ? 0.90 : (mouse.containsMouse ? 1.04 : 1.0))

                        Behavior on radius { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: LivePalette.color.onSurface
                            opacity: mouse.pressed ? 0.14 : (mouse.containsMouse ? 0.08 : 0)
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 24
                            source: entry.appItem
                                ? Quickshell.iconPath(entry.appItem.desktop ? entry.appItem.desktop.icon : entry.appItem.appId, "application-x-executable")
                                : ""
                        }
                    }

                    Timer { id: middleBounce; interval: 130 }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        preventStealing: true
                        cursorShape: entry.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                        property real pressItemY: 0
                        property bool dragged: false

                        onEntered: {
                            if (root.draggingIndex >= 0 || overlay.menuOpen) return;
                            root.hoveredId = entry.modelData;
                            root.hoveredY = root.itemCenterInScreen(entry);
                            tooltipDelay.restart();
                        }
                        onExited: {
                            if (root.hoveredId === entry.modelData) {
                                root.hoveredId = "";
                                tooltipDelay.stop();
                                overlay.hideTooltip();
                            }
                        }
                        onPressed: function(event) {
                            if (event.button === Qt.LeftButton) {
                                pressItemY = mapToItem(items, event.x, event.y).y;
                                dragged = false;
                            }
                        }
                        onPositionChanged: function(event) {
                            if (pressed && (pressedButtons & Qt.LeftButton)) {
                                const curItemY = mapToItem(items, event.x, event.y).y;
                                const distance = curItemY - pressItemY;
                                if (!dragged && Math.abs(distance) > 8) {
                                    dragged = true;
                                    tooltipDelay.stop();
                                    overlay.hideTooltip();
                                    root.draggingIndex = entry.index;
                                    root.dropIndex = entry.index;
                                }
                                if (dragged) {
                                    root.dragDeltaY = distance;
                                    const rawTarget = root.draggingIndex + Math.round(distance / root.slotStep);
                                    root.dropIndex = Math.max(0, Math.min(root.entryIds.length - 1, rawTarget));

                                    const viewY = mapToItem(viewport, event.x, event.y).y;
                                    if (viewport.contentHeight > viewport.height) {
                                        root.autoScrollDir = viewY < 24 ? -1 : (viewY > viewport.height - 24 ? 1 : 0);
                                    } else {
                                        root.autoScrollDir = 0;
                                    }
                                }
                            }
                        }
                        onReleased: function(event) {
                            if (event.button === Qt.LeftButton && dragged) {
                                const fromIdx = root.draggingIndex;
                                const toIdx = root.dropIndex;
                                const visibleIds = root.entryIds.slice();
                                root.clearDragState();
                                dragged = false;
                                if (fromIdx >= 0 && toIdx >= 0 && fromIdx !== toIdx && root.controller) {
                                    root.controller.move(fromIdx, toIdx, visibleIds);
                                }
                            }
                        }
                        onCanceled: {
                            root.clearDragState();
                            dragged = false;
                        }
                        onClicked: function(event) {
                            if (!entry.appItem || !root.controller) return;
                            if (event.button === Qt.RightButton) {
                                tooltipDelay.stop();
                                overlay.openMenu(entry.modelData, root.itemCenterInScreen(entry));
                            } else if (event.button === Qt.MiddleButton) {
                                middleBounce.restart();
                                root.controller.launchNew(entry.appItem);
                            } else if (!dragged) {
                                root.controller.activate(entry.appItem, root.monitor);
                            }
                        }
                    }
                }
            }
        }
    }

    // Overflow scroll edge fades (only when scrollable)
    Rectangle {
        anchors { left: viewport.left; right: viewport.right; top: viewport.top }
        height: 14
        visible: viewport.contentHeight > viewport.height && !viewport.atYBeginning
        gradient: Gradient {
            GradientStop { position: 0.0; color: LivePalette.color.surface }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {
        anchors { left: viewport.left; right: viewport.right; bottom: viewport.bottom }
        height: 14
        visible: viewport.contentHeight > viewport.height && !viewport.atYEnd
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: LivePalette.color.surface }
        }
    }
    Rectangle {
        readonly property bool overflow: viewport.contentHeight > viewport.height + 1
        visible: overflow
        anchors.right: viewport.right
        anchors.rightMargin: 2
        width: 2
        radius: 1
        y: viewport.y + (viewport.height - height) * (viewport.contentY / Math.max(1, viewport.contentHeight - viewport.height))
        height: Math.max(16, viewport.height * (viewport.height / Math.max(1, viewport.contentHeight)))
        color: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.45)
    }
}
