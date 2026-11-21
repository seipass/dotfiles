import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "Theme.js" as Theme

PanelWindow {
    id: launcherWindow
    property var taskbarController

    property bool launcherOpen: false
    property bool closing: false
    property bool emojiMode: false
    property var toolResult: ({})
    readonly property var toolMatch: searchInput.text.match(/^\/(calc|time|color|qr|weather)[ \t]+(.*)$/i)
    readonly property string mode: emojiMode ? "emoji" : toolMatch ? toolMatch[1].toLowerCase() : ""
    readonly property string argument: emojiMode ? searchInput.text.trim() : toolMatch ? toolMatch[2].trim() : ""
    readonly property string requestKey: mode + "\n" + argument
    readonly property var commands: [["/calc", "Calculator"], ["/time", "Time and time zones"],
        ["/color", "Color converter"], ["/qr", "QR code"], ["/weather", "Weather forecast"], ["/web", "Search the web"]]
    readonly property bool commandPicker: !emojiMode && /^\/[a-z]*$/i.test(searchInput.text)
    readonly property var commandResults: commands.filter(item => item[0].startsWith(searchInput.text.toLowerCase()))
    readonly property bool webSearch: !emojiMode && /^\/web\s+\S/i.test(searchInput.text)
    function completeCommand(index) {
        const item = commandResults[index];
        if (item) searchInput.text = item[0] + " ";
    }
    readonly property var hints: ({
        calc: "/calc 2π + sqrt(9)",
        time: "/time tokyo to london  ·  /time 23:30 + 2h - 15m + 1:45",
        color: "/color #a5c9ff  ·  /color rgb(165, 201, 255)",
        qr: "/qr https://example.com",
        weather: "/weather Tokyo  ·  Press Enter to fetch"
    })
    onRequestKeyChanged: {
        toolResult = {};
        toolDelay.stop();
        if (launcherOpen && mode && mode !== "weather" && (argument || emojiMode))
            toolDelay.restart();
    }
    function requestTool() {
        if (toolProcess.running || !mode || (!argument && !emojiMode)) return;
        toolProcess.key = requestKey;
        toolProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/launcher-tools.py", mode, argument];
        toolProcess.running = true;
    }
    Timer { id: toolDelay; interval: 120; onTriggered: launcherWindow.requestTool() }
    Process {
        id: toolProcess
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (toolProcess.key !== launcherWindow.requestKey || !launcherWindow.launcherOpen) return;
                try { launcherWindow.toolResult = JSON.parse(text); }
                catch (_) { launcherWindow.toolResult = {error: "Could not load results"}; }
            }
        }
        onExited: {
            if (launcherWindow.launcherOpen && key !== launcherWindow.requestKey && launcherWindow.mode !== "weather")
                toolDelay.restart();
        }
    }
    TextEdit { id: clipboard; visible: false }
    function copyResult(value) {
        clipboard.text = value;
        clipboard.selectAll();
        clipboard.copy();
        clipboard.text = "";
        closeLauncher();
    }
    ListModel {
        id: appListModel
    }

    onFilteredEntriesChanged: {
        syncAppListModel();
    }

    function syncAppListModel(): void {
        const target = filteredEntries;
        const targetIds = new Set();
        for (let i = 0; i < target.length; ++i) targetIds.add(target[i].id);

        // 1. Remove items that no longer match (triggers remove and displaced transitions)
        for (let i = appListModel.count - 1; i >= 0; --i) {
            const entry = appListModel.get(i).entry;
            if (!entry || !targetIds.has(entry.id)) {
                appListModel.remove(i);
            }
        }

        // 2. Insert or move items to match target order (triggers add and displaced transitions)
        for (let i = 0; i < target.length; ++i) {
            const t = target[i];
            let foundIdx = -1;
            for (let j = i; j < appListModel.count; ++j) {
                const item = appListModel.get(j).entry;
                if (item && item.id === t.id) {
                    foundIdx = j;
                    break;
                }
            }

            if (foundIdx === -1) {
                appListModel.insert(i, { entry: t });
            } else if (foundIdx !== i) {
                appListModel.move(foundIdx, i, 1);
            }
        }
    }

    property var filteredEntries: {
        const query = searchInput.text.trim().toLowerCase();
        return DesktopEntries.applications.values.map(entry => {
            const name = (entry.name || "").toLowerCase();
            const keywords = [entry.id, entry.genericName, ...(entry.keywords || [])].join(" ").toLowerCase();
            const score = !query || name === query ? 0
                : name.startsWith(query) ? 1
                : name.includes(query) ? 2
                : keywords.includes(query) ? 3
                : (entry.comment || "").toLowerCase().includes(query) ? 4 : -1;
            return { entry, score };
        }).filter(result => result.score >= 0)
          .sort((a, b) => a.score - b.score || a.entry.name.localeCompare(b.entry.name))
          .map(result => result.entry);
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: launcherOpen || closing
    focusable: launcherOpen
    color: "transparent"
    mask: null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: launcherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Invisible backdrop: intercept clicks outside launcherCard without darkening the screen
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: launcherWindow.closeLauncher()
        onWheel: function(wheel) { wheel.accepted = true; }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            launcherWindow.toggleLauncher(false);
        }
        function emoji(): void { launcherWindow.toggleLauncher(true); }
        function isOpen(): bool {
            return launcherWindow.launcherOpen;
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.motion.emphasized + 30
        onTriggered: launcherWindow.closing = false
    }

    function toggleLauncher(emoji): void {
        if (launcherOpen && emojiMode === emoji) {
            closeLauncher();
            return;
        }

        closeTimer.stop();
        emojiMode = emoji;

        for (let i = 0; i < Quickshell.screens.length; ++i) {
            const candidate = Quickshell.screens[i];
            const monitor = Hyprland.monitorFor(candidate);
            if (monitor !== null && monitor.focused) {
                screen = candidate;
                break;
            }
        }

        searchInput.text = "";
        syncAppListModel();
        appList.currentIndex = 0;
        launcherOpen = true;
        closing = false;
        if (emoji) toolDelay.restart();
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function closeLauncher(): void {
        launcherOpen = false;
        closing = true;
        closeTimer.restart();
    }

    function launchEntry(entry): void {
        if (entry === null || entry === undefined)
            return;

        closeLauncher();
        entry.execute();
    }

    function launchSelected(): void {
        if (commandPicker) { completeCommand(appList.currentIndex); return; }
        if (webSearch) {
            Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(searchInput.text.replace(/^\/web\s+/i, "").trim()));
            closeLauncher();
            return;
        }
        if (emojiMode) {
            const selected = (toolResult.emoji || [])[appList.currentIndex];
            if (selected) copyResult(selected[0]);
            return;
        }
        if (mode) {
            if (mode === "weather" || !toolResult.text) requestTool();
            else if (mode !== "qr") copyResult(toolResult.text);
            return;
        }
        if (appList.currentIndex >= 0 && appList.currentIndex < appList.count) {
            const item = appListModel.get(appList.currentIndex);
            if (item && item.entry) launchEntry(item.entry);
            else if (appList.currentIndex < filteredEntries.length) launchEntry(filteredEntries[appList.currentIndex]);
        }
    }

    Rectangle {
        id: launcherCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -slideOffset * height
        property real slideOffset: launcherWindow.launcherOpen ? 0 : 1
        width: Math.min(560, parent.width - 32)
        height: Math.min(launcherWindow.mode && !launcherWindow.emojiMode
                         ? (launcherWindow.toolResult.image ? 360 : 230) : 540, parent.height)
        radius: Theme.shape.dialogRadius
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: LivePalette.color.surface
        border.width: 0
        enabled: launcherWindow.launcherOpen

        Behavior on slideOffset {
            NumberAnimation {
                duration: launcherWindow.launcherOpen ? Theme.motion.emphasized : Theme.motion.exit
                easing.type: launcherWindow.launcherOpen ? Easing.OutQuint : Easing.InOutCubic
            }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic }
        }

        GridLayout {
            anchors.fill: parent
            anchors.margins: 18
            columns: 1
            rowSpacing: Theme.spacing.medium

            // M3 Search Bar (54px full pill)
            Rectangle {
                Layout.row: 1
                Layout.column: 0
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: height / 2
                color: LivePalette.color.surfaceContainerHigh
                border.width: 0

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 46
                    anchors.rightMargin: searchInput.text.length > 0 ? 44 : 18
                    verticalAlignment: TextInput.AlignVCenter
                    color: LivePalette.color.onSurface
                    selectionColor: LivePalette.color.primaryContainer
                    selectedTextColor: LivePalette.color.onSurface
                    font.family: "Google Sans Flex"
                    font.pixelSize: 15
                    clip: true
                    onTextChanged: {
                        appList.currentIndex = 0;
                    }
                    onAccepted: launcherWindow.launchSelected()
                    Keys.onTabPressed: if (launcherWindow.commandPicker) launcherWindow.completeCommand(appList.currentIndex)

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            launcherWindow.closeLauncher();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (appList.count > 0)
                                appList.currentIndex = Math.min(appList.count - 1, appList.currentIndex + 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (appList.count > 0)
                                appList.currentIndex = Math.max(0, appList.currentIndex - 1);
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 46
                    anchors.verticalCenter: parent.verticalCenter
                    text: launcherWindow.emojiMode ? "Search emoji…" : "Search apps or use /calc, /time, /color, /qr, /weather"
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 14
                    visible: searchInput.text.length === 0
                    enabled: false
                }
                SymbolIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "system-search-symbolic"
                    tint: LivePalette.color.primary
                    width: 18
                    height: 18
                }
                Rectangle {
                    visible: searchInput.text.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 15
                    color: clearSearchMouse.containsMouse ? LivePalette.color.surfaceContainer : "transparent"

                    SymbolIcon {
                        anchors.centerIn: parent
                        iconName: "window-close-symbolic"
                        tint: LivePalette.color.onSurfaceVariant
                        width: 15
                        height: 15
                    }
                    MouseArea {
                        id: clearSearchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                    }
                }
            }

            ListView {
                id: appList
                Layout.row: 0
                Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacing.extraSmall
                visible: !launcherWindow.mode || launcherWindow.emojiMode
                model: launcherWindow.commandPicker ? launcherWindow.commandResults
                    : launcherWindow.emojiMode ? (launcherWindow.toolResult.emoji || []) : appListModel
                currentIndex: 0
                highlight: Rectangle { radius: height / 2; color: LivePalette.color.primaryContainer }
                highlightMoveDuration: 180
                highlightMoveVelocity: -1
                onCountChanged: if (count && currentIndex < 0) currentIndex = 0

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                }

                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 160; easing.type: Easing.OutQuad }
                }

                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic }
                }

                delegate: Rectangle {
                    id: appRow
                    required property var model
                    required property var modelData
                    required property int index

                    readonly property var appEntry: launcherWindow.emojiMode ? null : (model.entry || modelData)

                    width: appList.width
                    height: 48
                    radius: Theme.shape.fullRadius
                    color: "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 11

                        IconImage {
                            visible: !launcherWindow.emojiMode && !!appRow.appEntry
                            source: visible ? Quickshell.iconPath(appRow.appEntry.icon, "application-x-executable") : ""
                            implicitSize: 26
                        }
                        Text {
                            visible: launcherWindow.emojiMode
                            text: visible ? (appRow.modelData ? appRow.modelData[0] : "") : ""
                            font.family: Theme.font.emoji
                            font.pixelSize: 24
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: launcherWindow.commandPicker && appRow.modelData ? appRow.modelData.join("  ·  ")
                                    : launcherWindow.emojiMode ? (appRow.modelData ? appRow.modelData[1] : "") : (appRow.appEntry ? appRow.appEntry.name : "")
                                color: LivePalette.color.onSurface
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: !launcherWindow.emojiMode && !!appRow.appEntry
                                text: visible ? (appRow.appEntry.genericName || appRow.appEntry.comment || "") : ""
                                color: LivePalette.color.onSurfaceVariant
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    TaskbarMenu {
                        id: appMenu
                        pinned: !launcherWindow.emojiMode && !!appRow.appEntry && launcherWindow.taskbarController.isPinned(appRow.appEntry.id)
                        onToggleRequested: if (appRow.appEntry) launcherWindow.taskbarController.togglePin(appRow.appEntry.id)
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: appList.currentIndex = appRow.index
                        onClicked: function(event) {
                            if (launcherWindow.commandPicker) {
                                if (event.button === Qt.LeftButton) launcherWindow.completeCommand(appRow.index);
                            } else if (launcherWindow.emojiMode) {
                                if (event.button === Qt.LeftButton && appRow.modelData) launcherWindow.copyResult(appRow.modelData[0]);
                            } else if (event.button === Qt.RightButton) {
                                appMenu.popup();
                            } else if (appRow.appEntry) {
                                launcherWindow.launchEntry(appRow.appEntry);
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: appList.count === 0
                    text: launcherWindow.webSearch ? "Press Enter to search the web" : "No results"
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 13
                }
            }
            Rectangle {
                Layout.row: 0
                Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !!launcherWindow.mode && !launcherWindow.emojiMode
                radius: 24
                color: LivePalette.color.surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 200
                        visible: !!launcherWindow.toolResult.image
                        source: launcherWindow.toolResult.image || ""
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        visible: !!launcherWindow.toolResult.color
                        color: launcherWindow.toolResult.color || "transparent"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: toolProcess.running ? "Working…" : (launcherWindow.toolResult.error
                              || launcherWindow.toolResult.text || launcherWindow.hints[launcherWindow.mode] || "")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: launcherWindow.toolResult.error ? LivePalette.color.error : LivePalette.color.onSurface
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            Text {
                Layout.row: 2
                Layout.column: 0
                Layout.alignment: Qt.AlignRight
                text: launcherWindow.emojiMode ? "Enter  Copy emoji    Esc  Close"
                    : launcherWindow.mode === "weather" ? "Enter  Fetch forecast    Esc  Close"
                    : launcherWindow.mode === "qr" ? "Esc  Close"
                    : launcherWindow.mode ? "Enter  Copy result    Esc  Close" : "Enter  Open    Esc  Close"
                color: LivePalette.color.onSurfaceVariant
                font.pixelSize: 11
            }
        }
    }
}
