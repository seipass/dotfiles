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
        NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutQuint }
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
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
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
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.joinRadius + 12
            anchors.rightMargin: 16
            anchors.topMargin: root.joinRadius + 16
            spacing: 3
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 34 : 0
                visible: root.menuPath.length > 1
                radius: 17
                color: backMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "‹   戻る"; color: LivePalette.color.onSurface; font.pixelSize: 13 }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.goBack() }
            }
            Repeater {
                model: opener.children
                delegate: Rectangle {
                    id: menuRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 1 : 36
                    radius: modelData.isSeparator ? 0 : 18
                    color: modelData.isSeparator ? LivePalette.color.outlineVariant : rowMouse.containsMouse && modelData.enabled ? LivePalette.color.surfaceContainerHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        visible: !menuRow.modelData.isSeparator
                        IconImage { implicitSize: 18; visible: !!menuRow.modelData.icon; source: menuRow.modelData.icon }
                        Text { Layout.fillWidth: true; text: menuRow.modelData.text; color: menuRow.modelData.enabled ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { visible: menuRow.modelData.hasChildren; text: "›"; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 18 }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
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
