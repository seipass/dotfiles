import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

PanelWindow {
    id: root
    property var shellState
    property bool opened: false
    property bool closing: false
    property real cursorX: 120
    property real cursorY: 120
    property int selectedIndex: 0

    readonly property real cardWidth: 364
    readonly property real cardHeight: 452
    readonly property var rawHistory: root.shellState ? (root.shellState.clipboardHistory || []) : []
    readonly property var filteredHistory: {
        const q = searchInput.text.trim().toLowerCase();
        if (!q) return rawHistory;
        return rawHistory.filter(item => {
            if (item.type === "image") {
                const meta = ("image " + (item.mime || "") + " " + (item.width || "") + "x" + (item.height || "")).toLowerCase();
                return meta.includes(q);
            }
            return (item.text || "").toLowerCase().includes(q);
        });
    }

    function formatSize(bytes) {
        const b = Number(bytes) || 0;
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB";
        if (b >= 1024) return Math.round(b / 1024) + " KB";
        return b + " B";
    }

    function formatMime(mime) {
        const parts = String(mime || "image/png").split("/");
        return (parts.length > 1 ? parts[1] : parts[0]).toUpperCase();
    }

    onFilteredHistoryChanged: {
        if (selectedIndex >= filteredHistory.length) selectedIndex = Math.max(0, filteredHistory.length - 1);
    }

    function togglePopup() {
        if (opened) {
            closePopup();
            return;
        }
        if (!cursorProcess.running) cursorProcess.running = true;
    }

    function openAt(targetScreen, localX, localY) {
        if (targetScreen) root.screen = targetScreen;
        const sw = (root.screen ? root.screen.width : 1920);
        const sh = (root.screen ? root.screen.height : 1080);
        const px = Math.max(12, Math.min(sw - cardWidth - 12, localX + 14));
        const py = Math.max(12, Math.min(sh - cardHeight - 12, localY + 14));
        cursorX = px;
        cursorY = py;
        searchInput.text = "";
        selectedIndex = 0;
        closeTimer.stop();
        closing = false;
        opened = true;
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function closePopup() {
        if (!opened) return;
        opened = false;
        closing = true;
        closeTimer.restart();
    }

    function selectCurrent() {
        if (selectedIndex >= 0 && selectedIndex < filteredHistory.length) {
            const item = filteredHistory[selectedIndex];
            if (item && root.shellState) root.shellState.copyClipboardEntry(item);
            closePopup();
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.togglePopup(); }
    }

    Process {
        id: cursorProcess
        command: ["python3", "-c",
            "import json,subprocess\n"
            + "def get(*a): return json.loads(subprocess.check_output(a, timeout=2))\n"
            + "p=get('hyprctl','cursorpos','-j'); ms=get('hyprctl','monitors','-j')\n"
            + "for m in ms:\n"
            + " w,h=m['width'],m['height']\n"
            + " if m.get('transform',0)%2: w,h=h,w\n"
            + " w/=m['scale']; h/=m['scale']\n"
            + " if m['x']<=p['x']<m['x']+w and m['y']<=p['y']<m['y']+h:\n"
            + "  print(f\"{m['name']}|{round(p['x']-m['x'])}|{round(p['y']-m['y'])}\"); break\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                let match = Quickshell.screens.length ? Quickshell.screens[0] : null;
                let lx = 200;
                let ly = 160;
                if (parts.length === 3) {
                    const found = Quickshell.screens.find(s => s.name === parts[0]);
                    if (found) match = found;
                    lx = Number(parts[1]) || 200;
                    ly = Number(parts[2]) || 160;
                }
                root.openAt(match, lx, ly);
            }
        }
        onExited: code => {
            if (code !== 0 && !root.opened) root.openAt(Quickshell.screens[0] || null, 200, 160);
        }
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: opened || closing
    focusable: opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: root.opened ? null : emptyRegion
    Region { id: emptyRegion; width: 0; height: 0 }

    anchors { left: true; right: true; top: true; bottom: true }

    Timer { id: closeTimer; interval: Theme.motion.fast + 20; onTriggered: root.closing = false }

    // Outside click dismiss
    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.closePopup()
    }

    // M3 Extra-Large Floating Clipboard Card near cursor
    Rectangle {
        id: card
        x: root.cursorX
        y: root.cursorY
        width: root.cardWidth
        height: root.cardHeight
        radius: 26
        color: LivePalette.color.surfaceContainer
        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.93
        transformOrigin: Item.TopLeft

        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.opened ? Theme.motion.standard : Theme.motion.fast; easing.type: Easing.OutQuint } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Clipboard"
                    font.family: "Ndot 55"
                    font.pixelSize: 20
                    color: LivePalette.color.onSurface
                }

                Rectangle {
                    height: 22
                    radius: 11
                    color: LivePalette.color.primaryContainer
                    width: cntText.implicitWidth + 14
                    Text {
                        id: cntText
                        anchors.centerIn: parent
                        text: String(root.rawHistory.length)
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: LivePalette.color.primary
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: root.rawHistory.length > 0
                    height: 30
                    radius: 15
                    color: LivePalette.color.surfaceContainerHigh
                    width: clearLabel.implicitWidth + 20
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: LivePalette.color.onSurface
                        opacity: clearMouse.pressed ? 0.14 : clearMouse.containsMouse ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                    }
                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: LivePalette.color.onSurface
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.shellState) root.shellState.clearClipboard()
                    }
                }

                HeaderIconButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 15
                    iconName: "window-close-symbolic"
                    label: "Close clipboard"
                    onClicked: root.closePopup()
                }
            }

            // M3 Search Pill
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 20
                color: LivePalette.color.surfaceContainerHigh

                SymbolIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 15
                    implicitHeight: 15
                    iconName: "system-search-symbolic"
                    tint: LivePalette.color.primary
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: LivePalette.color.onSurface
                    selectionColor: LivePalette.color.primaryContainer
                    selectedTextColor: LivePalette.color.onSurface
                    font.family: "Google Sans Flex"
                    font.pixelSize: 13
                    clip: true
                    onAccepted: root.selectCurrent()
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.closePopup();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.filteredHistory.length > 0)
                                root.selectedIndex = Math.min(root.filteredHistory.length - 1, root.selectedIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.filteredHistory.length > 0)
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 36
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "履歴を検索… (テキスト・画像)"
                    font.pixelSize: 12
                    color: LivePalette.color.onSurfaceVariant
                }
            }

            // History List (Text + Image Thumbnails)
            ListView {
                id: clipList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredHistory
                currentIndex: root.selectedIndex
                ScrollBar.vertical: ScrollBar { active: true }

                delegate: Rectangle {
                    id: clipRow
                    required property var modelData
                    required property int index
                    readonly property bool isImage: modelData.type === "image"
                    readonly property bool selected: root.selectedIndex === index
                    width: clipList.width - 4
                    implicitHeight: isImage ? 88 : Math.min(68, clipText.implicitHeight + 24)
                    radius: 16
                    color: selected ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainerHigh
                    scale: rowMouse.pressed ? 0.98 : 1.0
                    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: LivePalette.color.onSurface
                        opacity: rowMouse.pressed ? 0.12 : rowMouse.containsMouse ? 0.07 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                    }

                    // Text Entry Layout
                    RowLayout {
                        visible: !clipRow.isImage
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            id: clipText
                            Layout.fillWidth: true
                            text: (clipRow.modelData.text || "").replace(/\s+/g, " ")
                            textFormat: Text.PlainText
                            font.pixelSize: 12
                            font.weight: clipRow.selected ? Font.Medium : Font.Normal
                            color: LivePalette.color.onSurface
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: clipRow.modelData.time || ""
                            font.pixelSize: 10
                            color: clipRow.selected ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                        }
                    }

                    // Image Entry Layout
                    RowLayout {
                        visible: clipRow.isImage
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 108
                            Layout.preferredHeight: 72
                            radius: 12
                            color: LivePalette.color.surface
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: clipRow.isImage && clipRow.modelData.path ? ("file://" + clipRow.modelData.path) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                smooth: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    radius: 999
                                    color: clipRow.selected
                                        ? Qt.alpha(LivePalette.color.primary, 0.24)
                                        : LivePalette.color.primaryContainer
                                    implicitWidth: imgBadgeTxt.implicitWidth + 12
                                    implicitHeight: 20
                                    Text {
                                        id: imgBadgeTxt
                                        anchors.centerIn: parent
                                        text: root.formatMime(clipRow.modelData.mime)
                                        font.family: "Ioskeley Mono Term"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: LivePalette.color.primary
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: clipRow.modelData.time || ""
                                    font.pixelSize: 10
                                    color: clipRow.selected ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (clipRow.modelData.width > 0 && clipRow.modelData.height > 0)
                                    ? (clipRow.modelData.width + " × " + clipRow.modelData.height)
                                    : "Image"
                                font.family: "Ioskeley Mono Term"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: LivePalette.color.onSurface
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.formatSize(clipRow.modelData.size)
                                font.family: "Ioskeley Mono Term"
                                font.pixelSize: 11
                                color: LivePalette.color.onSurfaceVariant
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = clipRow.index
                        onClicked: {
                            const item = clipRow.modelData;
                            const st = root.shellState;
                            root.closePopup();
                            if (st) st.copyClipboardEntry(item);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: clipList.count === 0
                    text: root.rawHistory.length === 0 ? "コピーしたテキスト・画像が表示されます" : "一致する履歴がありません"
                    font.pixelSize: 12
                    color: LivePalette.color.onSurfaceVariant
                }
            }
        }
    }
}
