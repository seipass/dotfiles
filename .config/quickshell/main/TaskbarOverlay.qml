import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root

    property var controller: null
    property var monitor: null
    property bool currentMonitorOnly: false

    property string activeId: ""
    property real anchorY: 0
    property bool tipVisible: false
    property bool menuOpen: false
    property bool closing: false
    property bool allowMoveAnim: false

    readonly property bool shown: tipVisible || menuOpen
    readonly property var entry: root.controller && root.activeId
        ? root.controller.findEntry(root.activeId, root.monitor, root.currentMonitorOnly)
        : null
    readonly property string appTitle: {
        if (!entry) return "";
        if (entry.desktop && entry.desktop.name) return entry.desktop.name;
        return entry.appId || entry.id || "";
    }
    readonly property var entryWindows: entry ? (entry.windows || []) : []
    readonly property bool isPinned: !!(root.controller && entry && root.controller.isPinned(entry.id))
    readonly property bool canPin: !!(entry && entry.desktop)
    readonly property bool canLaunchNew: !!(entry && entry.desktop)

    function showTooltip(id, centerY) {
        if (menuOpen || !id) return;
        closeTimer.stop();
        closing = false;
        const switching = shown;
        allowMoveAnim = switching;
        activeId = id;
        anchorY = centerY;
        tipVisible = true;
        if (!switching) Qt.callLater(() => { allowMoveAnim = true; });
    }

    function hideTooltip() {
        if (menuOpen || !tipVisible) return;
        tipVisible = false;
        allowMoveAnim = false;
        closing = true;
        closeTimer.restart();
    }

    function openMenu(id, centerY) {
        if (!id) return;
        closeTimer.stop();
        closing = false;
        allowMoveAnim = shown;
        activeId = id;
        anchorY = centerY;
        tipVisible = false;
        menuOpen = true;
        Qt.callLater(() => {
            allowMoveAnim = true;
            card.forceActiveFocus();
        });
    }

    function closeMenu() {
        if (!menuOpen && !tipVisible) return;
        menuOpen = false;
        tipVisible = false;
        allowMoveAnim = false;
        closing = true;
        closeTimer.restart();
    }

    visible: shown || closing
    color: "transparent"
    focusable: menuOpen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: menuOpen ? null : emptyMask
    Region { id: emptyMask; width: 0; height: 0 }

    anchors { left: true; top: true }
    margins.left: Theme.shape.railReservation + 8
    margins.top: {
        const sh = root.screen ? root.screen.height : 1080;
        return Math.max(8, Math.min(sh - implicitHeight - 8, root.anchorY - (root.menuOpen ? 24 : implicitHeight / 2)));
    }
    Behavior on margins.top {
        enabled: root.allowMoveAnim
        NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic }
    }

    implicitWidth: root.menuOpen ? 268 : Math.min(256, Math.max(132, cardLayout.implicitWidth + 24))
    implicitHeight: cardLayout.implicitHeight + (root.menuOpen ? 20 : 16)

    Timer {
        id: closeTimer
        interval: Theme.motion.fast + 20
        onTriggered: {
            root.closing = false;
            if (!root.shown) root.activeId = "";
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: root.menuOpen
        windows: [root]
        onCleared: root.closeMenu()
    }

    onEntryChanged: if (shown && !entry) closeMenu()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: root.menuOpen ? 20 : 14
        color: LivePalette.color.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(LivePalette.color.outlineVariant, 0.45)
        focus: root.menuOpen
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1.0 : 0.94
        transformOrigin: Item.Left

        Keys.onEscapePressed: root.closeMenu()

        Behavior on radius { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutBack } }

        ColumnLayout {
            id: cardLayout
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: root.menuOpen ? 10 : 12
                rightMargin: root.menuOpen ? 10 : 12
                topMargin: root.menuOpen ? 10 : 8
            }
            spacing: root.menuOpen ? 4 : 3

            // Header: app name + window count / monitor summary
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.menuOpen ? 4 : 0
                Layout.rightMargin: root.menuOpen ? 4 : 0
                Layout.bottomMargin: root.menuOpen ? 2 : 0
                spacing: 8

                IconImage {
                    visible: root.menuOpen && !!root.entry
                    implicitSize: 18
                    source: root.entry
                        ? Quickshell.iconPath(root.entry.desktop ? root.entry.desktop.icon : root.entry.appId, "application-x-executable")
                        : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: root.appTitle
                        textFormat: Text.PlainText
                        color: LivePalette.color.onSurface
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const count = root.entryWindows.length;
                            if (count === 0) return root.isPinned ? "固定済み · 未起動" : "未起動";
                            const onHere = root.monitor
                                ? root.entryWindows.filter(w => w.monitor?.name === root.monitor.name).length
                                : count;
                            if (!root.currentMonitorOnly && root.monitor && onHere === 0) {
                                const mons = [...new Set(root.entryWindows.map(w => w.monitor?.name).filter(Boolean))];
                                return count + " ウィンドウ · " + (mons.join(", ") || "別モニター");
                            }
                            return count === 1 ? "実行中 (1 ウィンドウ)" : "実行中 (" + count + " ウィンドウ)";
                        }
                        textFormat: Text.PlainText
                        color: LivePalette.color.onSurfaceVariant
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // Tooltip-only compact window title list
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.menuOpen && root.entryWindows.length > 0
                spacing: 2

                Repeater {
                    model: !root.menuOpen ? root.entryWindows.slice(0, 3) : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 5; height: 5; radius: 3
                            color: modelData.activated ? LivePalette.color.primary : LivePalette.color.outlineVariant
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || root.appTitle
                            textFormat: Text.PlainText
                            color: modelData.activated ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
                            font.pixelSize: 11
                            font.weight: modelData.activated ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                        }
                        Text {
                            readonly property string monName: modelData.monitor?.name ?? ""
                            visible: !root.currentMonitorOnly && !!root.monitor && !!monName && monName !== root.monitor.name
                            text: monName
                            textFormat: Text.PlainText
                            color: LivePalette.color.primary
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }
                Text {
                    visible: root.entryWindows.length > 3
                    text: "他 +" + (root.entryWindows.length - 3) + " ウィンドウ"
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 10
                }
            }

            // Menu mode: separator + interactive window rows + actions
            Rectangle {
                visible: root.menuOpen
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                height: 1
                color: Qt.alpha(LivePalette.color.outlineVariant, 0.45)
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.menuOpen && root.entryWindows.length > 0
                spacing: 2

                Repeater {
                    model: root.menuOpen ? root.entryWindows.slice(0, 6) : []
                    delegate: Rectangle {
                        id: winRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 17
                        color: winMouse.containsMouse
                            ? LivePalette.color.primaryContainer
                            : (modelData.activated ? Qt.alpha(LivePalette.color.primaryContainer, 0.45) : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 6
                            spacing: 8

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: winRow.modelData.activated ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                            }

                            Text {
                                Layout.fillWidth: true
                                text: winRow.modelData.title || root.appTitle
                                textFormat: Text.PlainText
                                color: LivePalette.color.onSurface
                                font.pixelSize: 12
                                font.weight: winRow.modelData.activated ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                readonly property string monName: winRow.modelData.monitor?.name ?? ""
                                visible: !root.currentMonitorOnly && !!root.monitor && !!monName && monName !== root.monitor.name
                                text: monName
                                textFormat: Text.PlainText
                                color: LivePalette.color.onSurfaceVariant
                                font.pixelSize: 10
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 12
                                color: closeWinMouse.containsMouse ? LivePalette.color.errorContainer : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                                SymbolIcon {
                                    anchors.centerIn: parent
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    iconName: "window-close-symbolic"
                                    tint: closeWinMouse.containsMouse ? LivePalette.color.error : LivePalette.color.onSurfaceVariant
                                }
                                MouseArea {
                                    id: closeWinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(ev) {
                                        ev.accepted = true;
                                        if (root.controller) root.controller.closeWindow(winRow.modelData);
                                        if (root.entryWindows.length <= 1) root.closeMenu();
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: winMouse
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: 32 }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.controller) root.controller.focusWindow(winRow.modelData);
                                root.closeMenu();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    height: 1
                    color: Qt.alpha(LivePalette.color.outlineVariant, 0.45)
                }
            }

            // Action: New Window
            Rectangle {
                visible: root.menuOpen && root.canLaunchNew
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: newWinMouse.containsMouse ? LivePalette.color.primaryContainer : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10
                    SymbolIcon {
                        implicitWidth: 16; implicitHeight: 16
                        iconName: "window-new-symbolic"
                        tint: LivePalette.color.primary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "新しいウィンドウを開く"
                        color: LivePalette.color.onSurface
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    id: newWinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.controller && root.entry) root.controller.launchNew(root.entry);
                        root.closeMenu();
                    }
                }
            }

            // Action: Pin / Unpin
            Rectangle {
                visible: root.menuOpen
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: root.canPin && pinMouse.containsMouse ? LivePalette.color.primaryContainer : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10
                    SymbolIcon {
                        implicitWidth: 16; implicitHeight: 16
                        iconName: root.isPinned ? "list-remove-symbolic" : "view-pin-symbolic"
                        tint: root.canPin ? LivePalette.color.primary : LivePalette.color.outlineVariant
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !root.canPin ? "固定不可 (.desktop 未検出)"
                            : (root.isPinned ? "固定を解除" : "タスクバーに固定")
                        color: root.canPin ? LivePalette.color.onSurface : LivePalette.color.outlineVariant
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    hoverEnabled: root.canPin
                    enabled: root.canPin
                    cursorShape: root.canPin ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.controller && root.entry) root.controller.togglePin(root.entry.id);
                        root.closeMenu();
                    }
                }
            }

            // Action: Close All Windows
            Rectangle {
                visible: root.menuOpen && root.entryWindows.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: closeAllMouse.containsMouse ? LivePalette.color.errorContainer : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10
                    SymbolIcon {
                        implicitWidth: 16; implicitHeight: 16
                        iconName: "window-close-symbolic"
                        tint: LivePalette.color.error
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.entryWindows.length > 1 ? "すべて終了 (" + root.entryWindows.length + ")" : "終了"
                        color: LivePalette.color.error
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    id: closeAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.controller && root.entry) {
                            root.controller.closeWindows(root.entry, root.monitor, root.currentMonitorOnly);
                        }
                        root.closeMenu();
                    }
                }
            }
        }
    }
}
