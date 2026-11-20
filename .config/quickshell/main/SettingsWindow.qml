import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "Theme.js" as Theme

Window {
    id: root
    FontLoader { id: settingsFont; source: "fonts/GoogleSansFlex.ttf" }
    readonly property string uiFont: settingsFont.status === FontLoader.Ready ? settingsFont.name : Qt.application.font.family

    property alias weatherCity: saved.weatherCity
    property alias wallpaper: saved.wallpaper
    property alias desktopClock: saved.desktopClock
    property alias showTray: saved.showTray
    property alias showTaskbar: saved.showTaskbar
    property alias islandDisplay: saved.islandDisplay
    property alias islandPlugin: saved.islandPlugin
    property alias page: persisted.page

    property string pendingPaletteMode: ""
    property string pendingPaletteSeed: ""
    property bool paletteQueued: false
    property bool paletteFailed: false

    // Responsive breakpoint: compact when window width is under 720
    readonly property bool isCompact: width < 720

    Component.onCompleted: {
        if (saved.paletteColors) LivePalette.apply(saved.paletteColors);
        if (saved.paletteMode !== "auto" || !root.wallpaper) root.applyPalette(saved.paletteMode);
    }

    property string pickerKind: ""
    property string pickerError: ""
    function chooseFile(kind) {
        if (filePicker.running) return;
        pickerError = "";
        pickerKind = kind;
        filePicker.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/portal-file-picker.py", kind];
        filePicker.running = true;
    }

    Process {
        id: filePicker
        stdout: StdioCollector {
            onStreamFinished: {
                const uri = this.text.trim();
                if (!uri.startsWith("file://")) return;
                if (root.pickerKind === "wallpaper") root.setWallpaper(uri);
                else if (root.pickerKind === "plugin") {
                    saved.islandPlugin = uri;
                    saved.islandDisplay = "custom";
                    saved.sync();
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) root.pickerError = "File selection was cancelled or failed.";
        }
    }

    // Weather auto-suggest process
    property var citySuggestions: []
    property bool searchingCities: false
    function searchCity(query) {
        if (!query || query.trim().length < 2) {
            citySuggestions = [];
            searchingCities = false;
            return;
        }
        citySearchProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/city-search.py", query.trim()];
        citySearchProcess.running = true;
        searchingCities = true;
    }

    Process {
        id: citySearchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.citySuggestions = JSON.parse(this.text.trim());
                } catch(_) {
                    root.citySuggestions = [];
                }
                root.searchingCities = false;
            }
        }
        onExited: {
            root.searchingCities = false;
        }
    }

    Timer {
        id: cityDebounce
        interval: 320
        repeat: false
        onTriggered: root.searchCity(cityInput.text)
    }

    onPageChanged: {
        pageAnim.restart();
    }

    ParallelAnimation {
        id: pageAnim
        NumberAnimation {
            target: pageContent
            property: "opacity"
            from: 0.35
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pageContent
            property: "y"
            from: 14
            to: 0
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    PersistentProperties {
        id: persisted
        reloadableId: "settingsWindowState"
        property int page: 0
    }

    function runPalette() {
        paletteQueued = false;
        paletteProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/apply-palette.py", pendingPaletteMode, pendingPaletteSeed, "--sync-desktop"];
        paletteProcess.running = true;
    }

    IpcHandler {
        target: "palette"
        function status(): string { return saved.paletteMode + "|" + LivePalette.color.primary + "|" + saved.value("paletteMode", "?"); }
        function select(mode: string): void {
            if (["auto", "pink", "blue", "green"].includes(mode)) root.applyPalette(mode);
        }
    }

    function applyPalette(mode) {
        saved.paletteMode = mode;
        saved.setValue("paletteMode", mode);
        saved.sync();
        let seed = "#ffb0ca";
        let bestScore = -1;
        for (const c of wallpaperColors.colors) {
            const high = Math.max(c.r, c.g, c.b);
            const low = Math.min(c.r, c.g, c.b);
            const score = (high - low) * (1 - Math.abs((high + low) / 2 - 0.5));
            if (score > bestScore) { bestScore = score; seed = c.toString(); }
        }
        pendingPaletteMode = mode;
        pendingPaletteSeed = seed;
        paletteQueued = true;
        if (!paletteProcess.running) runPalette();
    }

    Process {
        id: paletteProcess
        property string resultText: ""
        stdout: StdioCollector {
            onStreamFinished: paletteProcess.resultText = this.text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim()) console.warn("Could not generate palette: " + this.text.trim())
        }
        onExited: function(exitCode, exitStatus) {
            if (!root.paletteQueued) {
                root.paletteFailed = exitCode !== 0 || !LivePalette.apply(resultText);
                if (!root.paletteFailed) {
                    saved.paletteColors = resultText;
                    saved.setValue("paletteColors", resultText);
                    saved.sync();
                }
            }
            resultText = "";
            if (root.paletteQueued) Qt.callLater(root.runPalette);
        }
    }

    function open(targetScreen) {
        const target = targetScreen && Array.from(Qt.application.screens).find(display => display.name === targetScreen.name);
        if (target && screen !== target) screen = target;
        cityInput.text = weatherCity;
        citySuggestions = [];
        show();
        requestActivate();
    }

    IpcHandler {
        target: "settings"
        function open(): void { root.open(null); }
    }

    function setWallpaper(path) {
        saved.wallpaper = path;
        saved.setValue("wallpaper", path);
        saved.sync();
    }

    Settings {
        id: saved
        location: "file://" + Quickshell.env("HOME") + "/.config/quickshell/main/dashboard.ini"
        category: "Dashboard"
        property string weatherCity: ""
        property string wallpaper: ""
        property bool desktopClock: false
        property bool showTray: true
        property bool showTaskbar: true
        property string paletteMode: "pink"
        property string paletteColors: ""
        property string islandDisplay: "music"
        property string islandPlugin: ""
    }

    ColorQuantizer {
        id: wallpaperColors
        source: root.wallpaper
        depth: 3
        rescaleSize: 64
        onColorsChanged: if (saved.paletteMode === "auto" && root.wallpaper && colors.length) root.applyPalette("auto")
    }

    onWallpaperChanged: if (saved.paletteMode === "auto" && !wallpaper) applyPalette("auto")

    visible: false
    title: "Quickshell Settings"
    width: 980
    height: 660
    minimumWidth: 540
    minimumHeight: 460
    color: LivePalette.color.surface

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ================= Sidebar (Responsive width) =================
        Rectangle {
            Layout.preferredWidth: root.isCompact ? 68 : 236
            Layout.fillHeight: true
            color: LivePalette.color.surfaceContainer

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Qt.alpha(LivePalette.color.onSurface, 0.08)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.isCompact ? 10 : 16
                spacing: 6

                // App Branding Header
                RowLayout {
                    Layout.topMargin: 4
                    Layout.bottomMargin: 14
                    Layout.alignment: root.isCompact ? Qt.AlignHCenter : Qt.AlignLeft
                    spacing: 12

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 12
                        color: Qt.alpha(LivePalette.color.primary, 0.16)
                        border.color: Qt.alpha(LivePalette.color.primary, 0.3)
                        border.width: 1

                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 20
                            implicitHeight: 20
                            iconName: "preferences-system-symbolic"
                            tint: LivePalette.color.primary
                        }
                    }

                    ColumnLayout {
                        visible: !root.isCompact
                        spacing: 1
                        Text {
                            font.family: root.uiFont
                            text: "Settings"
                            color: LivePalette.color.onSurface
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            font.family: root.uiFont
                            text: "Quickshell Desktop"
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 11
                        }
                    }
                }

                // Nav Items
                Repeater {
                    model: [
                        { name: "Dashboard", icon: "view-grid-symbolic" },
                        { name: "Weather", icon: "weather-clear-symbolic" },
                        { name: "Wallpaper", icon: "image-x-generic-symbolic" },
                        { name: "Colors", icon: "applications-graphics-symbolic" },
                        { name: "Top Bar", icon: "view-more-symbolic" },
                        { name: "About", icon: "help-about-symbolic" }
                    ]
                    delegate: Rectangle {
                        id: nav
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: root.page === nav.index
                            ? Qt.alpha(LivePalette.color.primary, 0.15)
                            : navMouse.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.05) : "transparent"
                        border.width: root.page === nav.index ? 1 : 0
                        border.color: Qt.alpha(LivePalette.color.primary, 0.25)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Active Indicator pill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: root.isCompact ? 2 : 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3.5
                            height: root.page === nav.index ? 20 : 0
                            radius: 2
                            color: LivePalette.color.primary
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }

                        // Compact icon center / Full row
                        Item {
                            anchors.fill: parent

                            SymbolIcon {
                                visible: root.isCompact
                                anchors.centerIn: parent
                                implicitWidth: 19
                                implicitHeight: 19
                                iconName: nav.modelData.icon
                                tint: root.page === nav.index ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                            }

                            RowLayout {
                                visible: !root.isCompact
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12
                                spacing: 12

                                SymbolIcon {
                                    implicitWidth: 17
                                    implicitHeight: 17
                                    iconName: nav.modelData.icon
                                    tint: root.page === nav.index ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                }

                                Text {
                                    Layout.fillWidth: true
                                    font.family: root.uiFont
                                    text: nav.modelData.name
                                    color: root.page === nav.index ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
                                    font.pixelSize: 13
                                    font.weight: root.page === nav.index ? Font.DemiBold : Font.Normal
                                }
                            }
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = nav.index
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ================= Content Area =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: pageScroll
                anchors.fill: parent
                clip: true
                contentHeight: pageContent.implicitHeight + 80
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    id: vbar
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                Connections {
                    target: root
                    function onPageChanged() { pageScroll.contentY = 0; }
                }

                ColumnLayout {
                    id: pageContent
                    x: root.isCompact ? 20 : 36
                    y: 0
                    width: pageScroll.width - (root.isCompact ? 40 : 72)
                    spacing: 20

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Item { height: root.isCompact ? 16 : 28 }

                    // Page Header
                    ColumnLayout {
                        spacing: 4
                        Text {
                            font.family: root.uiFont
                            text: ["Dashboard", "Weather", "Wallpaper", "Colors", "Top Bar", "About"][root.page]
                            color: LivePalette.color.onSurface
                            font.pixelSize: root.isCompact ? 22 : 26
                            font.weight: Font.DemiBold
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            text: root.page === 0 ? "Configure widgets, quick shortcuts, and interactive features of the dashboard panel."
                                : root.page === 1 ? "Set your city to receive real-time weather and forecast updates in your panel."
                                : root.page === 2 ? "Select high-resolution desktop backgrounds across all connected displays."
                                : root.page === 3 ? "Customize the Material You dynamic theme and system accent colors."
                                : root.page === 4 ? "Customize the dynamic island and widgets on your top bar."
                                : "Comprehensive system, hardware, and display specifications."
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }
                    }

                    // ================= PAGE 0: DASHBOARD =================
                    ColumnLayout {
                        visible: root.page === 0
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 14
                            color: LivePalette.color.surfaceContainer
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                            border.width: 1
                            implicitHeight: dashQuickCol.implicitHeight + 36

                            ColumnLayout {
                                id: dashQuickCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 10
                                        color: Qt.alpha(LivePalette.color.primary, 0.12)
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            iconName: "system-run-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "Quick System Actions & Launchers"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: "Directly open system monitors, sound controls, or restart shell services"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                // Responsive Buttons Flow
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    readonly property int btnCols: width > 520 ? 3 : 1
                                    readonly property real btnW: Math.floor((width - (btnCols - 1) * spacing) / btnCols)

                                    SettingsActionButton {
                                        width: parent.btnW
                                        iconName: "utilities-system-monitor-symbolic"
                                        text: "Task Manager (htop)"
                                        onClicked: Quickshell.execDetached(["kitty", "-e", "htop"])
                                    }

                                    SettingsActionButton {
                                        width: parent.btnW
                                        iconName: "audio-volume-high-symbolic"
                                        text: "Audio Mixer (pavucontrol)"
                                        onClicked: Quickshell.execDetached(["pavucontrol"])
                                    }

                                    SettingsActionButton {
                                        width: parent.btnW
                                        iconName: "view-refresh-symbolic"
                                        text: "Reload Quickshell"
                                        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exec", "qs -c main"])
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 14
                            color: LivePalette.color.surfaceContainer
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                            border.width: 1
                            implicitHeight: dashGuideCol.implicitHeight + 36

                            ColumnLayout {
                                id: dashGuideCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 10
                                        color: Qt.alpha(LivePalette.color.primary, 0.12)
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            iconName: "help-browser-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "Interactive Panel Shortcuts"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: "Master gesture and mouse shortcuts for the dashboard popover"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(LivePalette.color.onSurface, 0.05) }

                                ColumnLayout {
                                    spacing: 12
                                    RowLayout {
                                        spacing: 12
                                        SymbolIcon { implicitWidth: 16; implicitHeight: 16; iconName: "preferences-system-time-symbolic"; tint: LivePalette.color.primary }
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            font.family: root.uiFont
                                            text: "Clicking the clock toggles the dashboard popover with real-time calendar and media."
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 13
                                        }
                                    }
                                    RowLayout {
                                        spacing: 12
                                        SymbolIcon { implicitWidth: 16; implicitHeight: 16; iconName: "audio-volume-high-symbolic"; tint: LivePalette.color.primary }
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            font.family: root.uiFont
                                            text: "Hover the volume bar and scroll the wheel to raise/lower volume smoothly in 1% steps."
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 13
                                        }
                                    }
                                    RowLayout {
                                        spacing: 12
                                        SymbolIcon { implicitWidth: 16; implicitHeight: 16; iconName: "media-playback-start-symbolic"; tint: LivePalette.color.primary }
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            font.family: root.uiFont
                                            text: "The built-in media widget controls MPRIS players (Spotify, Brave, MPV) with album art."
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ================= PAGE 1: WEATHER =================
                    ColumnLayout {
                        visible: root.page === 1
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 14
                            color: LivePalette.color.surfaceContainer
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                            border.width: 1
                            implicitHeight: weatherCol.implicitHeight + 36

                            ColumnLayout {
                                id: weatherCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 10
                                        color: Qt.alpha(LivePalette.color.primary, 0.12)
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            iconName: "weather-clear-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "City Location & Autocomplete"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: "Type to view matching cities from Open-Meteo and select your location."
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    TextField {
                                        id: cityInput
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        font.family: root.uiFont
                                        font.pixelSize: 13
                                        placeholderText: "Type a city (e.g. Tokyo, Nagoya, London, Paris)..."
                                        color: LivePalette.color.onSurface
                                        placeholderTextColor: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.6)
                                        selectionColor: LivePalette.color.primaryContainer
                                        leftPadding: 14
                                        rightPadding: 14

                                        background: Rectangle {
                                            radius: 10
                                            color: cityInput.activeFocus ? LivePalette.color.surface : Qt.alpha(LivePalette.color.surface, 0.6)
                                            border.width: cityInput.activeFocus ? 2 : 1
                                            border.color: cityInput.activeFocus ? LivePalette.color.primary : Qt.alpha(LivePalette.color.onSurface, 0.12)
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }

                                        onTextChanged: {
                                            cityDebounce.restart();
                                        }

                                        onAccepted: {
                                            root.weatherCity = text.trim();
                                            saved.sync();
                                            root.citySuggestions = [];
                                        }
                                        Keys.onEscapePressed: {
                                            root.citySuggestions = [];
                                            root.close();
                                        }
                                    }

                                    SettingsActionButton {
                                        primary: true
                                        iconName: "document-save-symbolic"
                                        text: "Save"
                                        enabled: cityInput.text.trim() !== root.weatherCity
                                        onClicked: {
                                            root.weatherCity = cityInput.text.trim();
                                            saved.sync();
                                            root.citySuggestions = [];
                                        }
                                    }
                                }

                                // Suggestions List Box
                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: root.citySuggestions.length > 0
                                    radius: 12
                                    color: LivePalette.color.surface
                                    border.color: Qt.alpha(LivePalette.color.primary, 0.3)
                                    border.width: 1
                                    implicitHeight: suggestCol.implicitHeight + 12

                                    ColumnLayout {
                                        id: suggestCol
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 2

                                        Repeater {
                                            model: root.citySuggestions
                                            delegate: Rectangle {
                                                id: sugRow
                                                required property var modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                radius: 8
                                                color: sugMouse.containsMouse ? Qt.alpha(LivePalette.color.primary, 0.15) : "transparent"

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 10

                                                    SymbolIcon {
                                                        implicitWidth: 15
                                                        implicitHeight: 15
                                                        iconName: "mark-location-symbolic"
                                                        tint: sugMouse.containsMouse ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                                    }

                                                    Text {
                                                        font.family: root.uiFont
                                                        text: sugRow.modelData.name
                                                        color: LivePalette.color.onSurface
                                                        font.pixelSize: 13
                                                        font.weight: Font.Medium
                                                    }

                                                    Text {
                                                        font.family: root.uiFont
                                                        text: (sugRow.modelData.admin ? sugRow.modelData.admin + ", " : "") + sugRow.modelData.country
                                                        color: LivePalette.color.onSurfaceVariant
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        font.family: root.uiFont
                                                        text: "Select"
                                                        color: LivePalette.color.primary
                                                        font.pixelSize: 11
                                                        font.weight: Font.DemiBold
                                                        visible: sugMouse.containsMouse
                                                    }
                                                }

                                                MouseArea {
                                                    id: sugMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        cityInput.text = sugRow.modelData.name;
                                                        root.weatherCity = sugRow.modelData.name;
                                                        saved.sync();
                                                        root.citySuggestions = [];
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 8
                                    SymbolIcon {
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        iconName: cityInput.text.trim() !== root.weatherCity ? "emblem-important-symbolic" : "emblem-default-symbolic"
                                        tint: cityInput.text.trim() !== root.weatherCity ? LivePalette.color.primary : "#4ade80"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        font.family: root.uiFont
                                        text: cityInput.text.trim() !== root.weatherCity ? "Unsaved changes pending"
                                            : root.weatherCity ? "Currently active city: " + root.weatherCity : "Weather updates are disabled"
                                        color: LivePalette.color.onSurfaceVariant
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }

                    // ================= PAGE 2: WALLPAPER =================
                    ColumnLayout {
                        visible: root.page === 2
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 14
                            color: LivePalette.color.surfaceContainer
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                            border.width: 1
                            implicitHeight: wallCol.implicitHeight + 36

                            ColumnLayout {
                                id: wallCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 10
                                        color: Qt.alpha(LivePalette.color.primary, 0.12)
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            iconName: "image-x-generic-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "Current Desktop Wallpaper"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: root.wallpaper ? root.wallpaper.replace("file://", "") : "No wallpaper image configured"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Wallpaper Image Preview Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.isCompact ? 160 : 220
                                    radius: 12
                                    clip: true
                                    color: LivePalette.color.surface
                                    border.color: Qt.alpha(LivePalette.color.onSurface, 0.1)
                                    border.width: 1

                                    Image {
                                        anchors.fill: parent
                                        visible: root.wallpaper.length > 0
                                        source: root.wallpaper
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: root.wallpaper.length > 0
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.alpha(LivePalette.color.surface, 0.45) }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        visible: !root.wallpaper
                                        spacing: 8
                                        SymbolIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            iconName: "image-missing-symbolic"
                                            tint: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.5)
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: "No wallpaper selected"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 13
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        visible: !!root.pickerError && root.pickerKind === "wallpaper"
                                        text: root.pickerError
                                        color: LivePalette.color.error
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                    }

                                    Item { Layout.fillWidth: true; visible: !root.pickerError || root.pickerKind !== "wallpaper" }

                                    SettingsActionButton {
                                        visible: root.wallpaper.length > 0
                                        iconName: "edit-delete-symbolic"
                                        text: "Clear"
                                        onClicked: root.setWallpaper("")
                                    }

                                    SettingsActionButton {
                                        primary: true
                                        iconName: "document-open-symbolic"
                                        enabled: !filePicker.running
                                        text: filePicker.running && root.pickerKind === "wallpaper" ? "Opening Picker…" : "Select Image…"
                                        onClicked: root.chooseFile("wallpaper")
                                    }
                                }
                            }
                        }
                    }

                    // ================= PAGE 3: COLORS =================
                    ColumnLayout {
                        visible: root.page === 3
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 14
                            color: LivePalette.color.surfaceContainer
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                            border.width: 1
                            implicitHeight: colCol.implicitHeight + 36

                            ColumnLayout {
                                id: colCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 10
                                        color: Qt.alpha(LivePalette.color.primary, 0.12)
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            iconName: "applications-graphics-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "System Color Theme"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: root.paletteFailed ? "Failed to generate dynamic palette. Reverting."
                                                : "Material You dynamic extraction adapts to your current background or preset."
                                            color: root.paletteFailed ? LivePalette.color.error : LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                // Responsive Color Tiles Flow
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    readonly property int colCols: width > 540 ? 4 : width > 320 ? 2 : 1
                                    readonly property real colTileW: Math.floor((width - (colCols - 1) * spacing) / colCols)

                                    Repeater {
                                        model: [
                                            { label: "Wallpaper Auto", mode: "auto", color: "#b8a6d9", desc: "Dynamic from image" },
                                            { label: "Sakura Pink", mode: "pink", color: "#ffb0ca", desc: "Gentle pink accent" },
                                            { label: "Sky Blue", mode: "blue", color: "#a9c7ff", desc: "Cool serene blue" },
                                            { label: "Forest Green", mode: "green", color: "#a6d0a0", desc: "Natural soft green" }
                                        ]
                                        delegate: Rectangle {
                                            id: paletteOption
                                            required property var modelData
                                            width: parent.colTileW
                                            height: 104
                                            radius: 12
                                            color: saved.paletteMode === modelData.mode ? Qt.alpha(LivePalette.color.primary, 0.12) :
                                                   palMouse.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.05) : LivePalette.color.surface
                                            border.width: saved.paletteMode === modelData.mode ? 2 : 1
                                            border.color: saved.paletteMode === modelData.mode ? LivePalette.color.primary : Qt.alpha(LivePalette.color.onSurface, 0.08)

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 14
                                                spacing: 6

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Rectangle {
                                                        width: 24
                                                        height: 24
                                                        radius: 12
                                                        color: paletteOption.modelData.color
                                                        border.color: Qt.alpha(paletteOption.modelData.color, 0.4)
                                                        border.width: 2

                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: saved.paletteMode === paletteOption.modelData.mode
                                                            text: "✓"
                                                            font.family: root.uiFont
                                                            font.pixelSize: 12
                                                            font.weight: Font.Bold
                                                            color: "#1b2636"
                                                        }
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                }

                                                Text {
                                                    font.family: root.uiFont
                                                    text: paletteOption.modelData.label
                                                    color: LivePalette.color.onSurface
                                                    font.pixelSize: 13
                                                    font.weight: saved.paletteMode === paletteOption.modelData.mode ? Font.DemiBold : Font.Normal
                                                }

                                                Text {
                                                    font.family: root.uiFont
                                                    text: paletteOption.modelData.desc
                                                    color: LivePalette.color.onSurfaceVariant
                                                    font.pixelSize: 11
                                                }
                                            }

                                            MouseArea {
                                                id: palMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.applyPalette(paletteOption.modelData.mode)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ================= PAGE 4: TOP BAR =================
                    ColumnLayout {
                        visible: root.page === 4
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 14
                            color: LivePalette.color.surfaceContainer
                            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                            border.width: 1
                            implicitHeight: topBarCol.implicitHeight + 36

                            ColumnLayout {
                                id: topBarCol
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16

                                RowLayout {
                                    spacing: 12
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 10
                                        color: Qt.alpha(LivePalette.color.primary, 0.12)
                                        SymbolIcon {
                                            anchors.centerIn: parent
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            iconName: "view-more-symbolic"
                                            tint: LivePalette.color.primary
                                        }
                                    }
                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            font.family: root.uiFont
                                            text: "Left Island Display Content"
                                            color: LivePalette.color.onSurface
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            font.family: root.uiFont
                                            text: "Configure the left segment of your panel dynamic island"
                                            color: LivePalette.color.onSurfaceVariant
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { mode: "music", title: "Music & Active Window", detail: "Displays currently playing media metadata or active application title", icon: "audio-x-generic-symbolic" },
                                            { mode: "none", title: "Hidden (Blank)", detail: "Keeps the left pill empty for a minimalist compact appearance", icon: "view-conceal-symbolic" },
                                            { mode: "custom", title: "Custom QML Component", detail: "Loads an external custom QML widget or battery extension", icon: "applications-engineering-symbolic" }
                                        ]
                                        delegate: Rectangle {
                                            id: islandOpt
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 64
                                            radius: 12
                                            color: saved.islandDisplay === modelData.mode ? Qt.alpha(LivePalette.color.primary, 0.12) :
                                                   islandMouse.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.05) : LivePalette.color.surface
                                            border.width: saved.islandDisplay === modelData.mode ? 1.5 : 1
                                            border.color: saved.islandDisplay === modelData.mode ? LivePalette.color.primary : Qt.alpha(LivePalette.color.onSurface, 0.08)

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 14
                                                spacing: 14

                                                Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 8
                                                    color: saved.islandDisplay === islandOpt.modelData.mode ? Qt.alpha(LivePalette.color.primary, 0.2) : Qt.alpha(LivePalette.color.onSurface, 0.05)
                                                    SymbolIcon {
                                                        anchors.centerIn: parent
                                                        implicitWidth: 16
                                                        implicitHeight: 16
                                                        iconName: islandOpt.modelData.icon
                                                        tint: saved.islandDisplay === islandOpt.modelData.mode ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text {
                                                        font.family: root.uiFont
                                                        text: islandOpt.modelData.title
                                                        color: LivePalette.color.onSurface
                                                        font.pixelSize: 13
                                                        font.weight: saved.islandDisplay === islandOpt.modelData.mode ? Font.DemiBold : Font.Normal
                                                    }
                                                    Text {
                                                        font.family: root.uiFont
                                                        text: islandOpt.modelData.detail
                                                        color: LivePalette.color.onSurfaceVariant
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                Rectangle {
                                                    width: 20
                                                    height: 20
                                                    radius: 10
                                                    color: "transparent"
                                                    border.color: saved.islandDisplay === islandOpt.modelData.mode ? LivePalette.color.primary : Qt.alpha(LivePalette.color.onSurface, 0.2)
                                                    border.width: 2

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 10
                                                        height: 10
                                                        radius: 5
                                                        color: LivePalette.color.primary
                                                        visible: saved.islandDisplay === islandOpt.modelData.mode
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: islandMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (islandOpt.modelData.mode === "custom" && !saved.islandPlugin) {
                                                        root.chooseFile("plugin");
                                                        return;
                                                    }
                                                    saved.islandDisplay = islandOpt.modelData.mode;
                                                    saved.sync();
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    radius: 12
                                    color: Qt.alpha(LivePalette.color.surface, 0.7)
                                    border.color: Qt.alpha(LivePalette.color.onSurface, 0.08)
                                    border.width: 1
                                    implicitHeight: customPlugCol.implicitHeight + 24
                                    visible: saved.islandDisplay === "custom"

                                    ColumnLayout {
                                        id: customPlugCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    font.family: root.uiFont
                                                    text: "Custom QML File"
                                                    color: LivePalette.color.onSurface
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    font.family: root.uiFont
                                                    text: saved.islandPlugin ? saved.islandPlugin.replace("file://", "") : "No QML file configured yet"
                                                    color: LivePalette.color.onSurfaceVariant
                                                    font.pixelSize: 11
                                                    elide: Text.ElideMiddle
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            SettingsActionButton {
                                                iconName: "document-open-symbolic"
                                                text: filePicker.running ? "Picking…" : saved.islandPlugin ? "Change…" : "Choose…"
                                                onClicked: root.chooseFile("plugin")
                                            }
                                        }

                                        Text {
                                            font.family: root.uiFont
                                            text: "Notice: Custom QML items run with full Quickshell system privileges. Select trusted files only."
                                            color: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.8)
                                            font.pixelSize: 11
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ================= PAGE 5: ABOUT =================
                    SystemAbout {
                        Layout.fillWidth: true
                        visible: root.page === 5
                        fontFamily: root.uiFont
                    }

                    Item { height: 20 }
                }
            }
        }
    }
}
