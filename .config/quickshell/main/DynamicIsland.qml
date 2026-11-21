import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "Theme.js" as Theme

PanelWindow {
    id: root

    property var panelDate: new Date()
    property int volumePercent: 0
    property bool volumeMuted: false
    property bool volumeAvailable: false
    property string networkLabel: "OFF"
    property string weatherTemp: ""
    property string weatherDescription: ""
    property string weatherIcon: "weather-clear-symbolic"
    property var earthquakeInfo: ({})
    property var earthquakeHistory: []
    property bool earthquakeLoading: false
    property bool earthquakeLive: false
    signal earthquakeRefreshRequested()
    property var settingsController
    property bool entered: false
    property bool expanded: false
    property string expandedView: "dashboard"
    property real dashboardOpacity: 0
    readonly property var player: Mpris.players.values.find(p => p.isPlaying)
        || Mpris.players.values[0] || null

    implicitHeight: root.screen ? root.screen.height : 1080
    color: "transparent"
    exclusiveZone: Theme.shape.islandReservation
    mask: root.expanded || island.height > Theme.shape.islandHeight + 1 ? null : islandRegion
    focusable: false

    anchors {
        left: true
        right: true
        top: true
    }

    WlrLayershell.layer: WlrLayer.Overlay

    Region { id: islandRegion; item: island }

    // The main layer starts to the right of the reserved left bar.
    PanelWindow {
        screen: root.screen
        visible: root.expanded && !root.fullscreenActive
        implicitWidth: Theme.shape.railReservation
        anchors { left: true; top: true; bottom: true }
        color: "transparent"
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.expanded = false
        }
    }

    Variants {
        model: Quickshell.screens.filter(screen => screen !== root.screen)
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.expanded && !root.fullscreenActive
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            focusable: false
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.expanded = false
            }
        }
    }

    readonly property real maxPanelHeight: root.screen ? root.screen.height - 40 : 1040
    readonly property real dashboardHeight: Math.min(700, maxPanelHeight)
    readonly property real earthquakeHeight: Math.min(640, maxPanelHeight)
    readonly property real targetExpandedHeight: expandedView === "earthquake" ? earthquakeHeight : dashboardHeight

    MouseArea {
        anchors.fill: parent
        enabled: root.expanded
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.expanded = false
    }

    readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool fullscreenActive: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
    visible: !fullscreenActive
    onFullscreenActiveChanged: if (fullscreenActive) root.expanded = false
    readonly property int workspaceId: root.hyprMonitor !== null
        && root.hyprMonitor.activeWorkspace !== null
        ? root.hyprMonitor.activeWorkspace.id : 1

    FontLoader {
        id: clockFont
        source: "Ndot55-Regular.otf"
    }

    Component.onCompleted: Qt.callLater(function() {
        root.entered = true;
    })

    Rectangle {
        id: island

        x: Math.round((root.screen.width - width) / 2 - (root.screen.width - parent.width))
        y: root.entered ? Theme.shape.islandInset : -18
        width: Math.min(parent.width - 32, Theme.shape.islandWidth)
        height: root.expanded ? root.targetExpandedHeight : Theme.shape.islandHeight
        radius: Theme.shape.islandRadius
        color: LivePalette.color.surface
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.shape.islandRadius
        bottomRightRadius: Theme.shape.islandRadius
        border.width: 0
        opacity: root.entered ? 1 : 0
        clip: false

        Behavior on height {
            NumberAnimation {
                duration: root.expanded ? Theme.motion.emphasized : Theme.motion.exit
                easing.type: root.expanded ? Easing.OutQuint : Easing.InOutCubic
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: Theme.motion.standard + 80
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.motion.emphasized
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motion.standard
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
                easing.type: Easing.OutCubic
            }
        }

        // Consume clicks on the panel background; controls above this area
        // receive their own clicks before the outside-dismiss handler.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: function(event) { event.accepted = true; }
        }

        MouseArea {
            x: 180
            y: 0
            width: Math.max(0, parent.width - 360)
            height: Theme.shape.islandHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.expanded && root.expandedView === "dashboard") root.expanded = false;
                else { root.expandedView = "dashboard"; root.expanded = true; }
            }
        }

        Shape {
            x: -12
            y: 0
            width: 12
            height: 12
            ShapePath {
                fillColor: LivePalette.color.surface
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: 12; y: 0 }
                PathLine { x: 12; y: 12 }
                PathCubic { control1X: 12; control1Y: 5.37; control2X: 6.63; control2Y: 0; x: 0; y: 0 }
            }
        }

        Shape {
            x: island.width
            y: 0
            width: 12
            height: 12
            ShapePath {
                fillColor: LivePalette.color.surface
                strokeWidth: 0
                startX: 12; startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: 12 }
                PathCubic { control1X: 0; control1Y: 5.37; control2X: 5.37; control2Y: 0; x: 12; y: 0 }
            }
        }

        Loader {
            id: islandExtension
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: 4
            width: 165
            height: Theme.shape.islandHeight - 8
            source: root.settingsController.islandDisplay === "music" ? "IslandMusic.qml"
                : root.settingsController.islandDisplay === "earthquake" ? "IslandEarthquake.qml"
                : root.settingsController.islandDisplay === "custom" ? root.settingsController.islandPlugin : ""
            onLoaded: {
                if (item && "paletteColors" in item) item.paletteColors = Qt.binding(() => LivePalette.color);
                if (item && "player" in item) item.player = Qt.binding(function() { return root.player; });
                if (item && "earthquakeInfo" in item) item.earthquakeInfo = Qt.binding(() => root.earthquakeInfo);
                if (item && "loading" in item) item.loading = Qt.binding(() => root.earthquakeLoading);
                if (item && item.clicked) item.clicked.connect(function() {
                    if (root.expanded && root.expandedView === "earthquake") {
                        root.expanded = false;
                    } else {
                        root.expandedView = "earthquake";
                        root.expanded = true;
                        root.earthquakeRefreshRequested();
                    }
                });
            }
        }

        Row {
            id: workspaceDots
            visible: false
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: (Theme.shape.islandHeight - height) / 2
            spacing: 4

            Repeater {
                model: 10

                delegate: Item {
                    id: workspaceSlot
                    required property int index

                    readonly property int workspaceId: index + 1
                    readonly property bool isCurrent: root.workspaceId === workspaceId

                    width: 16
                    height: 32

                    Rectangle {
                        id: dot
                        anchors.centerIn: parent
                        width: workspaceSlot.isCurrent ? 18 : 5
                        height: 5
                        radius: 3
                        color: workspaceSlot.isCurrent
                            ? LivePalette.color.primary : LivePalette.color.outlineVariant

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.motion.standard
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motion.fast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Hyprland.usingLua) {
                                Hyprland.dispatch(
                                    "hl.dsp.focus({ workspace = "
                                    + workspaceSlot.workspaceId + " })"
                                );
                            } else {
                                Hyprland.dispatch("workspace " + workspaceSlot.workspaceId);
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (Theme.shape.islandHeight - height) / 2
            text: Qt.formatDateTime(root.panelDate, "HH:mm")
            color: LivePalette.color.onSurface
            font.family: clockFont.status === FontLoader.Ready ? clockFont.name : "sans-serif"
            font.pixelSize: 20
            font.weight: Font.Normal
        }

        Row {
            id: statusItems
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: (Theme.shape.islandHeight - height) / 2
            spacing: 9

            Row {
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter

                SymbolIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: root.weatherTemp ? root.weatherIcon : "weather-severe-alert-symbolic"
                    tint: LivePalette.color.onSurface
                }

                Text {
                    text: root.weatherTemp || "—"
                    color: LivePalette.color.onSurface
                    font.family: clockFont.name
                    font.pixelSize: 14
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.expandedView = "dashboard"; root.expanded = true; } }
                }
            }

            Rectangle {
                width: 1
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                color: LivePalette.color.outlineVariant
            }

            Item {
                width: volumeContent.implicitWidth
                height: 28

                Row {
                    id: volumeContent
                    anchors.centerIn: parent
                    spacing: 5

                    SymbolIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: root.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                        tint: root.volumeMuted ? LivePalette.color.error : LivePalette.color.primary
                    }

                    Text {
                        text: root.volumeMuted ? "MUTE"
                            : root.volumeAvailable ? root.volumePercent + "%" : "—"
                        color: LivePalette.color.onSurface
                        font.family: clockFont.name
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                    }
                    onWheel: function(wheel) {
                        const amount = wheel.angleDelta.y > 0 ? "1%+" : "1%-";
                        Quickshell.execDetached([
                            "wpctl", "set-volume", "-l", "1",
                            "@DEFAULT_AUDIO_SINK@", amount
                        ]);
                    }
                }
            }
        }

        Item {
            id: dashboardViewport
            x: 22
            y: 50
            width: parent.width - 44
            height: Math.max(0, island.height - y - 12)
            clip: true
            visible: height > 0
            opacity: root.expanded ? 1 : 0
            enabled: root.expanded
            Behavior on opacity {
                NumberAnimation {
                    duration: root.expanded ? Theme.motion.standard : Theme.motion.fast
                    easing.type: Easing.OutCubic
                }
            }

            Dashboard {
                readonly property bool activeView: root.expandedView === "dashboard"
                x: activeView ? 0 : 28
                opacity: activeView ? 1 : 0
                scale: activeView ? 1 : 0.97
                visible: opacity > 0
                enabled: root.expanded && activeView
                width: parent.width
                height: root.dashboardHeight - 62
                transformOrigin: Item.Top
                Behavior on x { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast + 50; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                panelDate: root.panelDate
                player: root.player
                volumePercent: root.volumePercent
                volumeMuted: root.volumeMuted
                volumeAvailable: root.volumeAvailable
                weatherCity: root.settingsController.weatherCity
                weatherTemp: root.weatherTemp
                weatherDescription: root.weatherDescription
                weatherIcon: root.weatherIcon
                onSettingsRequested: {
                    root.expanded = false;
                    root.settingsController.open(root.screen);
                }
            }

            EarthquakePanel {
                readonly property bool activeView: root.expandedView === "earthquake"
                x: activeView ? 0 : -28
                opacity: activeView ? 1 : 0
                scale: activeView ? 1 : 0.97
                visible: opacity > 0
                enabled: root.expanded && activeView
                width: parent.width
                height: root.earthquakeHeight - 62
                transformOrigin: Item.Top
                Behavior on x { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast + 50; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                history: root.earthquakeHistory
                loading: root.earthquakeLoading
                liveMode: root.earthquakeLive
                onRefreshRequested: root.earthquakeRefreshRequested()
                onCloseRequested: root.expanded = false
            }
        }

        ColumnLayout {
            x: 22
            y: 52
            width: parent.width - 44
            spacing: 14
            visible: false
            opacity: Math.max(0, Math.min(1, (island.height - 90) / 100))

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: Qt.formatDateTime(root.panelDate, "HH:mm")
                        font.family: clockFont.name
                        font.pixelSize: 34
                        color: LivePalette.color.onSurface
                    }
                    Text {
                        text: Qt.formatDateTime(root.panelDate, "dddd, d MMMM")
                        font.pixelSize: 12
                        color: LivePalette.color.onSurfaceVariant
                    }
                }
                SymbolIcon {
                    iconName: "window-close-symbolic"
                    tint: LivePalette.color.onSurfaceVariant
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: 18
                color: LivePalette.color.surfaceContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 62
                        Layout.preferredHeight: 62
                        radius: 12
                        color: LivePalette.color.surfaceContainerHigh
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: root.player ? root.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        SymbolIcon {
                            anchors.centerIn: parent
                            visible: !root.player || !root.player.trackArtUrl
                            width: 28
                            height: 28
                            iconName: "audio-x-generic-symbolic"
                            tint: LivePalette.color.primary
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackTitle || root.player.identity) : "再生中のメディアはありません"
                            color: LivePalette.color.onSurface
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackArtist || root.player.identity) : "メディアを再生するとここに表示されます"
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 20
                            Repeater {
                                model: ["media-skip-backward-symbolic", "media-playback-start-symbolic", "media-skip-forward-symbolic"]
                                delegate: SymbolIcon {
                                    required property int index
                                    required property string modelData
                                    iconName: index === 1 && root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : modelData
                                    tint: LivePalette.color.primary
                                    opacity: root.player && (index === 0 ? root.player.canGoPrevious : index === 1 ? root.player.canTogglePlaying : root.player.canGoNext) ? 1 : 0.35
                                    width: 20
                                    height: 20
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        enabled: parent.opacity === 1
                                        onClicked: {
                                            if (index === 0) root.player.previous();
                                            else if (index === 1) root.player.togglePlaying();
                                            else root.player.next();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: 18
                color: LivePalette.color.surfaceContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    SymbolIcon {
                        iconName: root.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                        tint: LivePalette.color.primary
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        }
                    }
                    Slider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: root.volumePercent
                        enabled: root.volumeAvailable
                        onMoved: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)])
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: volumeSlider.availableWidth
                            height: 6
                            radius: 3
                            color: LivePalette.color.outlineVariant
                            Rectangle { width: parent.width * volumeSlider.visualPosition; height: parent.height; radius: 3; color: LivePalette.color.primary }
                        }
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: LivePalette.color.primary
                        }
                    }
                    Text { text: root.volumeAvailable ? root.volumePercent + "%" : "—"; color: LivePalette.color.onSurface; font.pixelSize: 12 }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 16
                color: LivePalette.color.surfaceContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    Text { text: "NETWORK"; font.family: clockFont.name; font.pixelSize: 15; color: LivePalette.color.onSurfaceVariant }
                    Item { Layout.fillWidth: true }
                    Text { text: root.networkLabel; font.family: clockFont.name; font.pixelSize: 15; color: LivePalette.color.primary }
                }
            }
        }
    }
}
