import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    property bool opened: false
    property bool closing: false
    property string pendingAction: ""
    property int focusedIndex: 0

    readonly property var secondaryActions: [
        { id: "reboot",  label: "再起動",     desc: "システムを再起動",     icon: "system-reboot-symbolic" },
        { id: "suspend", label: "スリープ",   desc: "省電力モードへ移行",   icon: "weather-clear-night-symbolic" },
        { id: "logout",  label: "ログアウト", desc: "セッションを終了",     icon: "system-log-out-symbolic" }
    ]

    function actionIdAt(idx) {
        if (idx === 0) return "poweroff";
        const item = secondaryActions[idx - 1];
        return item ? item.id : "";
    }

    function toggle() {
        if (opened) closeMenu();
        else {
            closeTimer.stop();
            confirmReset.stop();
            pendingAction = "";
            focusedIndex = 0;
            closing = false;
            opened = true;
            Qt.callLater(() => sheet.forceActiveFocus());
        }
    }
    function closeMenu() {
        if (!opened) return;
        confirmReset.stop();
        pendingAction = "";
        opened = false;
        closing = true;
        closeTimer.restart();
    }
    function runAction(id) {
        if (!id) return;
        if (id !== "suspend" && pendingAction !== id) {
            pendingAction = id;
            confirmReset.restart();
            return;
        }
        closeMenu();
        if (id === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"]);
        else if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"]);
        else if (id === "suspend") Quickshell.execDetached(["systemctl", "suspend"]);
        else if (id === "logout") Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit");
    }

    visible: opened || closing
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    focusable: opened
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: root.opened ? null : emptyRegion
    Region { id: emptyRegion; width: 0; height: 0 }

    Timer { id: closeTimer; interval: Theme.motion.exit + 20; onTriggered: root.closing = false }
    Timer { id: confirmReset; interval: 3500; onTriggered: root.pendingAction = "" }

    // Outside click to dismiss
    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closeMenu()
    }

    // M3 Extra-Large Floating Power Sheet
    Rectangle {
        id: sheet
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.shape.railWidth + 12
        anchors.bottomMargin: 12
        width: 344
        implicitHeight: sheetCol.implicitHeight + 36
        height: implicitHeight
        radius: 28
        color: LivePalette.color.surfaceContainer
        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.92
        transformOrigin: Item.BottomLeft
        focus: root.opened

        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.opened ? Theme.motion.standard : Theme.motion.exit; easing.type: Easing.OutQuint } }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeMenu();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                root.focusedIndex = (root.focusedIndex + 1) % 4;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                root.focusedIndex = (root.focusedIndex + 3) % 4;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.runAction(root.actionIdAt(root.focusedIndex));
                event.accepted = true;
            }
        }

        // Consume clicks inside the sheet
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.pendingAction = ""
        }

        ColumnLayout {
            id: sheetCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Header (Title left, Close X strictly pinned right)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Power"
                        font.family: "Ndot 55"
                        font.pixelSize: 20
                        color: LivePalette.color.onSurface
                    }
                    Text {
                        text: root.pendingAction ? "もう一度押すか Enter で実行します" : "Tab / 矢印で選択 · Esc で閉じる"
                        font.pixelSize: 11
                        color: root.pendingAction ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                HeaderIconButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 17
                    iconName: "window-close-symbolic"
                    label: "電源メニューを閉じる"
                    onClicked: root.closeMenu()
                }
            }

            // Primary Accessible Full-Width Shutdown Button
            Rectangle {
                id: shutdownBtn
                readonly property bool confirming: root.pendingAction === "poweroff"
                readonly property bool focused: root.opened && root.focusedIndex === 0
                Layout.fillWidth: true
                implicitHeight: 72
                radius: confirming ? 36 : 22
                color: confirming ? LivePalette.color.error : LivePalette.color.errorContainer
                border.width: focused ? 2 : 0
                border.color: confirming ? LivePalette.color.onSurface : LivePalette.color.error
                scale: shutdownMouse.pressed ? 0.97 : 1.0

                Accessible.role: Accessible.Button
                Accessible.name: confirming ? "シャットダウンを実行する" : "シャットダウン"
                Accessible.description: "システムの電源を切ります。誤操作防止のため2回押して実行します。"

                Behavior on radius { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                // M3 State Layer
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: shutdownBtn.confirming ? "#1a0607" : "#ffffff"
                    opacity: shutdownMouse.pressed ? 0.16 : shutdownMouse.containsMouse ? 0.10 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 16
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: shutdownBtn.confirming
                            ? Qt.alpha("#1a0607", 0.16)
                            : Qt.alpha("#ffffff", 0.14)

                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 22
                            implicitHeight: 22
                            iconName: "system-shutdown-symbolic"
                            tint: shutdownBtn.confirming ? "#1a0607" : "#ffdad6"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: shutdownBtn.confirming ? "もう一度押してシャットダウン" : "シャットダウン"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: shutdownBtn.confirming ? "#1a0607" : "#ffdad6"
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: shutdownBtn.confirming ? "クリックまたは Enter で電源を切ります" : "システムの電源を切る"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: shutdownBtn.confirming ? Qt.alpha("#1a0607", 0.82) : Qt.alpha("#ffdad6", 0.85)
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        visible: shutdownBtn.confirming
                        radius: 999
                        color: Qt.alpha("#1a0607", 0.18)
                        implicitWidth: confirmChip.implicitWidth + 16
                        implicitHeight: 24
                        Text {
                            id: confirmChip
                            anchors.centerIn: parent
                            text: "実行"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#1a0607"
                        }
                    }
                }

                MouseArea {
                    id: shutdownMouse
                    anchors.fill: parent
                    enabled: root.opened
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.focusedIndex = 0
                    onClicked: root.runAction("poweroff")
                }
            }

            // Secondary Actions Row (Reboot / Suspend / Logout)
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: root.secondaryActions
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool confirming: root.pendingAction === modelData.id
                        readonly property bool focused: root.opened && root.focusedIndex === (index + 1)
                        Layout.fillWidth: true
                        implicitHeight: 84
                        radius: confirming ? 28 : 20
                        color: confirming ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh
                        border.width: focused ? 2 : 0
                        border.color: confirming ? LivePalette.color.onSurface : LivePalette.color.primary
                        scale: tileMouse.pressed ? 0.96 : 1.0

                        Accessible.role: Accessible.Button
                        Accessible.name: confirming ? (modelData.label + "を実行する") : modelData.label
                        Accessible.description: modelData.desc

                        Behavior on radius { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: tile.confirming ? LivePalette.color.onPrimary : LivePalette.color.onSurface
                            opacity: tileMouse.pressed ? 0.14 : tileMouse.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 18
                                color: tile.confirming
                                    ? Qt.alpha(LivePalette.color.surface, 0.2)
                                    : LivePalette.color.primaryContainer

                                SymbolIcon {
                                    anchors.centerIn: parent
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    iconName: tile.modelData.icon
                                    tint: tile.confirming ? LivePalette.color.onPrimary : LivePalette.color.primary
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.confirming ? "実行する" : tile.modelData.label
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: tile.confirming ? LivePalette.color.onPrimary : LivePalette.color.onSurface
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            enabled: root.opened
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.focusedIndex = tile.index + 1
                            onClicked: root.runAction(tile.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
