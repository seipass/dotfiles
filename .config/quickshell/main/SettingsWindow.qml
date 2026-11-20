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
    property alias showTray: saved.showTray
    property alias showTaskbar: saved.showTaskbar
    property alias desktopClock: saved.desktopClock
    property alias islandDisplay: saved.islandDisplay
    property alias islandPlugin: saved.islandPlugin
    property alias page: persisted.page
    property string pendingPaletteMode: ""
    property string pendingPaletteSeed: ""
    property bool paletteQueued: false
    property bool paletteFailed: false
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
            if (exitCode !== 0) root.pickerError = "Could not select a file. Please try again.";
        }
    }
    onPageChanged: {
        pageFade.restart();
    }
    NumberAnimation {
        id: pageFade
        target: pageContent
        property: "opacity"
        from: 0.55
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
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
        property bool showTray: true
        property bool showTaskbar: true
        property bool desktopClock: false
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
    width: 860
    height: 580
    minimumWidth: 700
    minimumHeight: 480
    color: LivePalette.color.surface


    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0
        Rectangle {
            Layout.preferredWidth: 205
            Layout.fillHeight: true
            radius: 22
            color: LivePalette.color.surfaceContainer
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8
                RowLayout {
                    Layout.bottomMargin: 16
                    spacing: 10
                    Rectangle {
                        implicitWidth: 36; implicitHeight: 36; radius: 12
                        color: LivePalette.color.primaryContainer
                        SymbolIcon {
                            anchors.centerIn: parent
                            iconName: "emblem-system-symbolic"
                            tint: LivePalette.color.onSurface
                        }
                    }
                    Text { font.family: root.uiFont; text: "Settings"; color: LivePalette.color.onSurface; font.pixelSize: 23; font.weight: Font.DemiBold }
                }
                Repeater {
                    model: ["Dashboard", "Weather", "Wallpaper", "Colors", "Top Bar", "About"]
                    delegate: Rectangle {
                        id: nav
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 14
                        color: root.page === index ? LivePalette.color.primaryContainer : navMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.left: parent.left; anchors.leftMargin: 3; anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: root.page === nav.index ? 20 : 0; radius: 2; color: LivePalette.color.primary
                            Behavior on height { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                        }
                        SymbolIcon {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: ["view-grid-symbolic", "weather-clear-symbolic", "image-x-generic-symbolic", "applications-graphics-symbolic", "view-more-symbolic", "help-about-symbolic"][nav.index]
                            tint: root.page === nav.index ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                        }
                        Text { font.family: root.uiFont; anchors.left: parent.left; anchors.leftMargin: 40; anchors.verticalCenter: parent.verticalCenter; text: nav.modelData; color: root.page === nav.index ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant; font.pixelSize: 13; font.weight: root.page === nav.index ? Font.DemiBold : Font.Normal }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = nav.index }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { font.family: root.uiFont; text: "QUICKSHELL"; font.pixelSize: 11; font.letterSpacing: 1; color: LivePalette.color.onSurfaceVariant }
            }
        }
        Flickable {
            id: pageScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: pageContent.implicitHeight + 60
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            Connections {
                target: root
                function onPageChanged() { pageScroll.contentY = 0; }
            }
            ColumnLayout {
                id: pageContent
                x: 30
                y: 30
                width: pageScroll.width - 60
                spacing: 16
                Text {
                    font.family: root.uiFont
                    text: ["Dashboard", "Weather", "Wallpaper", "Colors", "Top Bar", "About"][root.page]
                    color: LivePalette.color.onSurface
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                }
                Text {
                    font.family: root.uiFont
                    Layout.fillWidth: true
                    text: root.page === 0 ? "Top bar controls" : root.page === 1 ? "Choose a city for weather updates." : root.page === 2 ? "Choose an image for all displays." : root.page === 3 ? "Choose a color palette for the shell." : root.page === 4 ? "Choose what appears on the left side of the top bar." : "System information for this computer."
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
                SystemAbout {
                    Layout.fillWidth: true
                    visible: root.page === 5
                    fontFamily: root.uiFont
                }
                Rectangle {
                    visible: root.page !== 5
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(options.implicitHeight + 40, root.page === 0 ? 170 : root.page === 1 ? 220 : root.page === 2 ? 260 : root.page === 3 ? 240 : 300)
                    radius: 24
                    color: LivePalette.color.surfaceContainer
                    border.color: Qt.alpha(LivePalette.color.onSurface, 0.12)
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        id: options
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10
                        Text {
                            font.family: root.uiFont
                            text: root.page === 0 ? "Controls" : root.page === 1 ? "City" : root.page === 2 ? "Wallpaper" : root.page === 3 ? "Color Palette" : "Display Content"
                            color: LivePalette.color.onSurface
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: root.page === 0
                            text: "Click the clock to open the dashboard. Click outside to close it.\nUse the scroll wheel or slider to adjust volume in 1% steps."
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 13
                            lineHeight: 1.35
                            wrapMode: Text.Wrap
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: root.page === 1
                            text: "Only the city name is sent to wttr.in. Leave it blank to disable weather updates."
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        TextField {
                            font.family: root.uiFont
                            id: cityInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            visible: root.page === 1
                            placeholderText: "e.g. Tokyo"
                            color: LivePalette.color.onSurface
                            placeholderTextColor: LivePalette.color.onSurfaceVariant
                            selectionColor: LivePalette.color.primaryContainer
                            leftPadding: 14
                            background: Rectangle {
                                radius: 12
                                color: LivePalette.color.surface
                                border.width: cityInput.activeFocus ? 2 : 1
                                border.color: cityInput.activeFocus ? LivePalette.color.primary : LivePalette.color.outlineVariant
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }
                            onAccepted: { root.weatherCity = text.trim(); saved.sync(); }
                            Keys.onEscapePressed: root.close()
                        }
                        Image {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 95
                            visible: root.page === 2 && root.wallpaper.length > 0
                            source: root.wallpaper
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            clip: true
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: root.page === 2 && !root.wallpaper
                            text: "No wallpaper selected."
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 12
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: root.page === 3
                            text: root.paletteFailed ? "Could not generate the palette. Please try again."
                                : "Auto uses colors from your wallpaper. Changes apply immediately."
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Flow {
                            Layout.fillWidth: true
                            visible: root.page === 3
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "Auto", mode: "auto", color: "#b8a6d9" },
                                    { label: "Pink", mode: "pink", color: "#ffb0ca" },
                                    { label: "Blue", mode: "blue", color: "#a9c7ff" },
                                    { label: "Green", mode: "green", color: "#a6d0a0" }
                                ]
                                delegate: Rectangle {
                                    id: paletteOption
                                    required property var modelData
                                    width: 95; height: 70; radius: 14
                                    color: LivePalette.color.surface
                                    border.width: saved.paletteMode === modelData.mode ? 2 : 1
                                    border.color: saved.paletteMode === modelData.mode ? LivePalette.color.primary : LivePalette.color.outlineVariant
                                    Column {
                                        anchors.centerIn: parent; spacing: 5
                                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 22; height: 22; radius: 11; color: paletteOption.modelData.color }
                                        Text { font.family: root.uiFont; anchors.horizontalCenter: parent.horizontalCenter; text: paletteOption.modelData.label; color: LivePalette.color.onSurface; font.pixelSize: 11 }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.applyPalette(paletteOption.modelData.mode) }
                                }
                            }
                        }
                        Repeater {
                            model: [
                                { mode: "music", title: "Music and Window", detail: "Track title and focused window title" },
                                { mode: "none", title: "Hide", detail: "Leave the left side of the top bar blank" },
                                { mode: "custom", title: "Custom QML", detail: "Use a QML file to replace the default display" }
                            ]
                            delegate: Button {
                                font.family: root.uiFont
                                id: option
                                required property var modelData
                                Layout.fillWidth: true
                                visible: root.page === 4
                                text: modelData.title
                                Accessible.description: modelData.detail
                                readonly property bool selected: saved.islandDisplay === modelData.mode
                                enabled: !filePicker.running
                                padding: 8
                                leftPadding: 12
                                background: Rectangle {
                                    radius: 12
                                    color: option.selected ? LivePalette.color.primaryContainer : option.hovered ? LivePalette.color.surfaceContainerHigh : LivePalette.color.surface
                                    border.width: option.activeFocus ? 2 : 0
                                    border.color: LivePalette.color.primary
                                    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                                }
                                contentItem: Column {
                                    spacing: 2
                                    Text { font.family: root.uiFont; text: (option.selected ? "✓  " : "") + option.text; color: LivePalette.color.onSurface; font.weight: Font.DemiBold }
                                    Text { font.family: root.uiFont; text: option.modelData.detail; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 13 }
                                }
                                onClicked: {
                                    if (modelData.mode === "custom" && !saved.islandPlugin) {
                                        root.chooseFile("plugin");
                                        return;
                                    }
                                    saved.islandDisplay = modelData.mode;
                                    saved.sync();
                                }
                            }
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: root.page === 4
                            text: saved.islandPlugin ? "Selected: " + saved.islandPlugin : "No file selected"
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                            wrapMode: Text.Wrap
                        }
                        SettingsActionButton {
                            font.family: root.uiFont
                            visible: root.page === 4
                            enabled: !filePicker.running
                            text: filePicker.running ? "Choosing a file…" : saved.islandPlugin ? "Change QML" : "Choose QML"
                            onClicked: root.chooseFile("plugin")
                        }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: root.page === 4
                            text: "QML runs with the same permissions as the shell. Choose only files you trust."
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                            font.family: root.uiFont
                            Layout.fillWidth: true
                            visible: !!root.pickerError && ((root.page === 4 && root.pickerKind === "plugin") || (root.page === 2 && root.pickerKind === "wallpaper"))
                            text: root.pickerError
                            color: LivePalette.color.error
                            wrapMode: Text.Wrap
                        }
                        SettingsActionButton {
                            font.family: root.uiFont
                            Layout.alignment: Qt.AlignRight
                            visible: root.page === 2 && root.wallpaper.length > 0
                            text: "Remove Wallpaper"
                            onClicked: root.setWallpaper("")
                        }
                        SettingsActionButton {
                            font.family: root.uiFont
                            primary: true
                            Layout.alignment: Qt.AlignRight
                            visible: root.page === 1 || root.page === 2
                            enabled: root.page === 1 ? cityInput.text.trim() !== root.weatherCity : !filePicker.running
                            text: root.page === 1 ? "Save" : "Choose Image"
                            onClicked: {
                                if (root.page === 1) {
                                    root.weatherCity = cityInput.text.trim();
                                    saved.sync();
                                } else root.chooseFile("wallpaper");
                            }
                        }
                    }
                }
                Text {
                    font.family: root.uiFont
                    visible: root.page === 1
                    text: root.page === 1 && cityInput.text.trim() !== root.weatherCity ? "Unsaved changes" : root.page === 1 && root.weatherCity ? "Saved · " + root.weatherCity : ""
                    color: LivePalette.color.onSurfaceVariant
                    font.pixelSize: 11
                }
            }
        }
    }
}
