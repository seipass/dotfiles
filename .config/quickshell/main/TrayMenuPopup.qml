import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "Theme.js" as Theme

PanelWindow {
    id: root
    property var menuHandle: null
    property var menuPath: []
    property real targetY: 0
    property bool shown: false
    property bool closing: false
    property bool contentShown: false
    property var pendingHandle: null
    readonly property real joinRadius: 20
    readonly property real outerRadius: 22
    readonly property real curve: 0.55228475
    readonly property bool hovered: hover.hovered
    function showMenu(handle, targetScreen, screenY) {
        if (!handle) return;
        closeTimer.stop();
        closing = false;
        targetY = screenY;
        if (shown && menuPath.length && menuPath[0] === handle) {
            switchTimer.stop();
            pendingHandle = null;
            contentShown = true;
            return;
        }
        if (shown && menuHandle) {
            pendingHandle = handle;
            contentShown = false;
            switchTimer.restart();
        } else {
            switchTimer.stop();
            pendingHandle = null;
            menuPath = [handle];
            menuHandle = handle;
            contentShown = true;
        }
        shown = true;
    }
    function closeMenu() {
        if (!shown) return;
        switchTimer.stop();
        pendingHandle = null;
        shown = false;
        closing = true;
        closeTimer.restart();
    }
    function openSubmenu(entry) {
        const path = menuPath.slice();
        path.push(entry);
        menuPath = path;
        menuHandle = entry;
    }
    function goBack() {
        const path = menuPath.slice();
        if (path.length < 2) return;
        path.pop();
        menuPath = path;
        menuHandle = path[path.length - 1];
    }
    visible: shown || closing
    implicitWidth: 340
    implicitHeight: Math.min(menuLayout.implicitHeight + 32 + joinRadius * 2, screen ? screen.height : 1080)
    margins.left: Theme.shape.railReservation
    margins.top: Math.max(0, Math.min(targetY - implicitHeight / 2, (screen ? screen.height : 1080) - implicitHeight))
    Behavior on margins.top {
        enabled: root.shown
        NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle }
    }
    anchors { left: true; top: true }
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    Timer {
        id: closeTimer
        interval: Theme.motion.fast
        onTriggered: {
            root.closing = false;
            root.menuHandle = null;
            root.menuPath = [];
        }
    }
    Timer {
        id: switchTimer
        interval: Theme.motion.fast
        onTriggered: {
            if (!root.pendingHandle || !root.shown) return;
            root.menuPath = [root.pendingHandle];
            root.menuHandle = root.pendingHandle;
            root.pendingHandle = null;
            root.contentShown = true;
        }
    }
    QsMenuOpener { id: opener; menu: root.menuHandle }
    Item {
        anchors.fill: parent
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1.0 : 0.92
        transformOrigin: Item.Left
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale {
            NumberAnimation {
                duration: root.shown ? Theme.motion.spatial : Theme.motion.exit
                easing.type: root.shown ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: root.shown ? Theme.motion.overshootStandard : 0
            }
        }
        HoverHandler { id: hover }
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                fillColor: LivePalette.color.surface
                strokeWidth: 0
                startX: 0
                startY: 0
                PathCubic {
                    control1X: 0; control1Y: root.joinRadius * root.curve
                    control2X: root.joinRadius * (1 - root.curve); control2Y: root.joinRadius
                    x: root.joinRadius; y: root.joinRadius
                }
                PathLine { x: root.width - root.outerRadius; y: root.joinRadius }
                PathCubic {
                    control1X: root.width - root.outerRadius * (1 - root.curve); control1Y: root.joinRadius
                    control2X: root.width; control2Y: root.joinRadius + root.outerRadius * (1 - root.curve)
                    x: root.width; y: root.joinRadius + root.outerRadius
                }
                PathLine { x: root.width; y: root.height - root.joinRadius - root.outerRadius }
                PathCubic {
                    control1X: root.width; control1Y: root.height - root.joinRadius - root.outerRadius * (1 - root.curve)
                    control2X: root.width - root.outerRadius * (1 - root.curve); control2Y: root.height - root.joinRadius
                    x: root.width - root.outerRadius; y: root.height - root.joinRadius
                }
                PathLine { x: root.joinRadius; y: root.height - root.joinRadius }
                PathCubic {
                    control1X: root.joinRadius * (1 - root.curve); control1Y: root.height - root.joinRadius
                    control2X: 0; control2Y: root.height - root.joinRadius * root.curve
                    x: 0; y: root.height
                }
                PathLine { x: 0; y: 0 }
            }
        }
        ColumnLayout {
            id: menuLayout
            opacity: root.contentShown ? 1 : 0
            scale: root.contentShown ? 1.0 : 0.96
            transformOrigin: Item.Left
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.joinRadius + 12
            anchors.rightMargin: 16
            anchors.topMargin: root.joinRadius + 16
            spacing: 3
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 38 : 0
                visible: root.menuPath.length > 1
                radius: backMouse.pressed ? 11 : 19
                color: LivePalette.color.surfaceContainerHigh
                scale: backMouse.pressed ? 0.95 : 1.0
                Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                Rectangle {
                    anchors.fill: parent; radius: parent.radius; color: LivePalette.color.onSurface
                    opacity: backMouse.pressed ? 0.12 : backMouse.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    SymbolIcon { implicitWidth: 16; implicitHeight: 16; iconName: "go-previous-symbolic"; tint: LivePalette.color.primary }
                    Text { Layout.fillWidth: true; text: "戻る"; color: LivePalette.color.onSurface; font.pixelSize: 13; font.weight: Font.Medium }
                }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goBack() }
            }
            Repeater {
                model: opener.children
                delegate: Item {
                    id: menuRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 9 : 38

                    Rectangle {
                        visible: menuRow.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        height: 1
                        color: Qt.alpha(LivePalette.color.outlineVariant, 0.55)
                    }

                    Rectangle {
                        visible: !menuRow.modelData.isSeparator
                        anchors.fill: parent
                        radius: rowMouse.pressed ? 11 : height / 2
                        color: rowMouse.containsMouse && menuRow.modelData.enabled ? LivePalette.color.primaryContainer : "transparent"
                        scale: rowMouse.pressed && menuRow.modelData.enabled ? 0.96 : 1.0
                        Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                            IconImage { implicitSize: 18; visible: !!menuRow.modelData.icon; source: menuRow.modelData.icon }
                            Text {
                                Layout.fillWidth: true
                                text: menuRow.modelData.text
                                color: menuRow.modelData.enabled ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
                                font.pixelSize: 13
                                font.weight: rowMouse.containsMouse && menuRow.modelData.enabled ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text { visible: menuRow.modelData.hasChildren; text: "›"; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 18 }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: menuRow.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
                            onClicked: {
                                if (menuRow.modelData.hasChildren) root.openSubmenu(menuRow.modelData);
                                else { menuRow.modelData.triggered(); root.closeMenu(); }
                            }
                        }
                    }
                }
            }
        }
    }
}
