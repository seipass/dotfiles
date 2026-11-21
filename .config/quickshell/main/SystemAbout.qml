import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Theme.js" as Theme

ColumnLayout {
    id: root
    required property string fontFamily
    property var info: ({ summary: {}, fetchRows: [], monitors: [], sections: [] })
    property bool failed: false
    property string copiedBadge: ""

    readonly property string monoFont: Theme.font.mono
    readonly property string displayFont: Theme.font.display
    readonly property bool isNarrow: width < 560

    readonly property string archAscii:
        "       /\\        \n" +
        "      /  \\       \n" +
        "     /\\   \\      \n" +
        "    /      \\     \n" +
        "   /   ,,   \\    \n" +
        "  /   |  |  -\\   \n" +
        " /_-''    ''-_\\  "

    readonly property var paletteSwatches: [
        { key: "primary", label: "primary", hex: String(LivePalette.color.primary) },
        { key: "primaryContainer", label: "pri-cont", hex: String(LivePalette.color.primaryContainer) },
        { key: "onPrimary", label: "on-pri", hex: String(LivePalette.color.onPrimary) },
        { key: "surface", label: "surface", hex: String(LivePalette.color.surface) },
        { key: "surfaceContainer", label: "surf-mid", hex: String(LivePalette.color.surfaceContainer) },
        { key: "surfaceContainerHigh", label: "surf-hi", hex: String(LivePalette.color.surfaceContainerHigh) },
        { key: "onSurface", label: "fg", hex: String(LivePalette.color.onSurface) },
        { key: "onSurfaceVariant", label: "fg-dim", hex: String(LivePalette.color.onSurfaceVariant) },
        { key: "outlineVariant", label: "outline", hex: String(LivePalette.color.outlineVariant) },
        { key: "error", label: "error", hex: String(LivePalette.color.error) }
    ]

    spacing: 16

    function copyToClipboard(text, label) {
        if (!text) return;
        Quickshell.clipboardText = text;
        root.copiedBadge = label || "Copied";
        copiedTimer.restart();
    }

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: root.copiedBadge = ""
    }

    onVisibleChanged: if (visible) collector.running = true
    Component.onCompleted: if (visible) collector.running = true

    Process {
        id: collector
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/system-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.info = parsed;
                    root.failed = false;
                } catch (_) {
                    root.failed = true;
                }
            }
        }
        onExited: code => { if (code !== 0) root.failed = true; }
    }

    // ================= 1. Unix Porn Fastfetch Hero Card =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: fetchCardCol.implicitHeight + 36
        radius: 26
        color: LivePalette.color.surfaceContainer
        clip: true

        // Subtle ambient corner glow
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.min(parent.width * 0.65, 360)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(LivePalette.color.primary, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: fetchCardCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            // Terminal Chrome Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Minimal tonal terminal dots
                Row {
                    spacing: 6
                    Repeater {
                        model: [
                            LivePalette.color.error,
                            LivePalette.color.primary,
                            LivePalette.color.onSurfaceVariant
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 10
                            height: 10
                            radius: 5
                            color: Qt.alpha(modelData, 0.85)
                        }
                    }
                }

                Text {
                    Layout.leftMargin: 6
                    text: ((root.info.summary && root.info.summary.userAtHost) || "user@arch") + "  —  fastfetch"
                    color: LivePalette.color.onSurfaceVariant
                    font.family: root.monoFont
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Copied feedback pill
                Rectangle {
                    visible: opacity > 0.01
                    opacity: root.copiedBadge !== "" ? 1.0 : 0.0
                    scale: root.copiedBadge !== "" ? 1.0 : 0.72
                    radius: 999
                    color: LivePalette.color.primaryContainer
                    implicitWidth: copiedLbl.implicitWidth + 18
                    implicitHeight: 26
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                    Text {
                        id: copiedLbl
                        anchors.centerIn: parent
                        text: root.copiedBadge
                        color: LivePalette.color.primary
                        font.family: root.monoFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                // Copy Fetch Pill Button
                Button {
                    id: copyFetchBtn
                    implicitHeight: 30
                    implicitWidth: copyFetchRow.implicitWidth + 20
                    hoverEnabled: true
                    background: Rectangle {
                        radius: copyFetchBtn.down ? 10 : 999
                        color: copyFetchBtn.down ? Qt.alpha(LivePalette.color.primary, 0.28) :
                               copyFetchBtn.hovered ? Qt.alpha(LivePalette.color.primary, 0.2) :
                               LivePalette.color.surfaceContainerHigh
                        scale: copyFetchBtn.down ? 0.93 : (copyFetchBtn.hovered ? 1.03 : 1.0)
                        Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                    }
                    contentItem: Row {
                        id: copyFetchRow
                        anchors.centerIn: parent
                        spacing: 6
                        SymbolIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 13
                            implicitHeight: 13
                            iconName: "edit-copy-symbolic"
                            tint: LivePalette.color.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Copy fetch"
                            color: LivePalette.color.onSurface
                            font.family: root.monoFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                    onClicked: {
                        const txt = root.info.summary && root.info.summary.fetchText;
                        if (txt) root.copyToClipboard(txt, "Fetch copied");
                    }
                }

                // Refresh Button
                Button {
                    id: heroRefreshBtn
                    implicitWidth: 30
                    implicitHeight: 30
                    hoverEnabled: true
                    background: Rectangle {
                        radius: heroRefreshBtn.down ? 9 : 999
                        color: heroRefreshBtn.down ? Qt.alpha(LivePalette.color.onSurface, 0.14) :
                               heroRefreshBtn.hovered ? LivePalette.color.surfaceContainerHigh : "transparent"
                        scale: heroRefreshBtn.down ? 0.88 : (heroRefreshBtn.hovered ? 1.06 : 1.0)
                        Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                    }
                    contentItem: SymbolIcon {
                        anchors.centerIn: parent
                        implicitWidth: 15
                        implicitHeight: 15
                        iconName: "view-refresh-symbolic"
                        tint: heroRefreshBtn.hovered ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                    }
                    onClicked: collector.running = true
                }
            }

            // Hairline separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.alpha(LivePalette.color.onSurface, 0.06)
            }

            // Main Fetch Body: ASCII Art + Spec Table
            GridLayout {
                Layout.fillWidth: true
                columns: root.isNarrow ? 1 : 2
                columnSpacing: 22
                rowSpacing: 14

                // Left: Arch ASCII Art Container
                Rectangle {
                    Layout.alignment: root.isNarrow ? Qt.AlignHCenter : Qt.AlignVCenter
                    Layout.preferredWidth: root.isNarrow ? Math.min(parent.width, 260) : 196
                    Layout.preferredHeight: 172
                    radius: 20
                    color: Qt.alpha(LivePalette.color.surface, 0.55)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.archAscii
                            color: LivePalette.color.primary
                            font.family: root.monoFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            lineHeight: 1.05
                            textFormat: Text.PlainText
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            radius: 999
                            color: LivePalette.color.primaryContainer
                            implicitWidth: distroTag.implicitWidth + 16
                            implicitHeight: 22

                            Text {
                                id: distroTag
                                anchors.centerIn: parent
                                text: ((root.info.summary && root.info.summary.osId) || "arch").toUpperCase() + " · " + ((root.info.summary && root.info.summary.arch) || "x86_64")
                                color: LivePalette.color.primary
                                font.family: root.monoFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Right: Ndot Header + Fastfetch Monospace Key-Value List
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // user@host in Ndot 55
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: (root.info.summary && root.info.summary.user) || "user"
                            color: LivePalette.color.primary
                            font.family: root.displayFont
                            font.pixelSize: 22
                        }
                        Text {
                            text: "@"
                            color: LivePalette.color.onSurfaceVariant
                            font.family: root.displayFont
                            font.pixelSize: 22
                        }
                        Text {
                            text: (root.info.summary && root.info.summary.hostname) || "desktop"
                            color: LivePalette.color.onSurface
                            font.family: root.displayFont
                            font.pixelSize: 22
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Dashed accent rule
                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        radius: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: LivePalette.color.primary }
                            GradientStop { position: 0.55; color: Qt.alpha(LivePalette.color.primary, 0.25) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // Fastfetch rows
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.info.fetchRows || []
                            delegate: RowLayout {
                                id: fetchRowItem
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    Layout.preferredWidth: 56
                                    text: fetchRowItem.modelData[0]
                                    color: LivePalette.color.primary
                                    font.family: root.monoFont
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: "▸"
                                    color: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.45)
                                    font.family: root.monoFont
                                    font.pixelSize: 11
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: fetchRowItem.modelData[1] || "—"
                                    color: LivePalette.color.onSurface
                                    font.family: root.monoFont
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }
            }

            // Live Material You Palette Swatch Strip (click to copy hex)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: swatchCol.implicitHeight + 18
                radius: 18
                color: Qt.alpha(LivePalette.color.surface, 0.55)

                ColumnLayout {
                    id: swatchCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "LIVE PALETTE"
                            color: LivePalette.color.onSurfaceVariant
                            font.family: root.monoFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: hoveredSwatchHint
                            text: "click a swatch to copy hex"
                            color: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.75)
                            font.family: root.monoFont
                            font.pixelSize: 10
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.paletteSwatches
                            delegate: Rectangle {
                                id: swatchBlock
                                required property var modelData
                                Layout.fillWidth: true
                                height: swatchHover.containsMouse ? 28 : 24
                                radius: 8
                                color: modelData.hex
                                border.width: 1
                                border.color: swatchHover.containsMouse
                                    ? LivePalette.color.onSurface
                                    : Qt.alpha(LivePalette.color.onSurface, 0.12)

                                scale: swatchHover.pressed ? 0.90 : 1.0
                                Behavior on height { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                                MouseArea {
                                    id: swatchHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: hoveredSwatchHint.text = swatchBlock.modelData.label + "  " + swatchBlock.modelData.hex.toUpperCase()
                                    onExited: hoveredSwatchHint.text = "click a swatch to copy hex"
                                    onClicked: root.copyToClipboard(swatchBlock.modelData.hex, "Copied " + swatchBlock.modelData.hex.toUpperCase())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= 2. Live Telemetry Bento Meters =================
    Flow {
        Layout.fillWidth: true
        spacing: 12

        readonly property int colCount: width > 560 ? 3 : width > 360 ? 2 : 1
        readonly property real tileWidth: Math.floor((width - (colCount - 1) * spacing) / colCount)

        // CPU Meter Card
        Rectangle {
            width: parent.tileWidth
            height: 112
            radius: 22
            color: LivePalette.color.surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: LivePalette.color.primaryContainer
                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 15
                            implicitHeight: 15
                            iconName: "utilities-system-monitor-symbolic"
                            tint: LivePalette.color.primary
                        }
                    }

                    Text {
                        text: "CPU"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: Boolean(root.info.summary && root.info.summary.cpuTemp)
                        radius: 999
                        color: LivePalette.color.surfaceContainerHigh
                        implicitWidth: cpuTempTxt.implicitWidth + 12
                        implicitHeight: 20
                        Text {
                            id: cpuTempTxt
                            anchors.centerIn: parent
                            text: (root.info.summary && root.info.summary.cpuTemp) || ""
                            color: LivePalette.color.primary
                            font.family: root.monoFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ((root.info.summary && root.info.summary.cpuLoadPct) || 0) + "%"
                        color: LivePalette.color.onSurface
                        font.family: root.displayFont
                        font.pixelSize: 22
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "load " + ((root.info.summary && root.info.summary.cpuLoad) || "—")
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 11
                    }
                }

                // M3 Expressive Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: LivePalette.color.surfaceContainerHigh
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: 4
                        width: Math.max(8, parent.width * Math.min(1, ((root.info.summary && root.info.summary.cpuLoadPct) || 0) / 100))
                        color: LivePalette.color.primary
                        Behavior on width { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle } }
                    }
                }
            }
        }

        // Memory Meter Card
        Rectangle {
            width: parent.tileWidth
            height: 112
            radius: 22
            color: LivePalette.color.surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: LivePalette.color.primaryContainer
                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 15
                            implicitHeight: 15
                            iconName: "drive-harddisk-symbolic"
                            tint: LivePalette.color.primary
                        }
                    }

                    Text {
                        text: "RAM"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (root.info.summary && root.info.summary.memory) || "—"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 10
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ((root.info.summary && root.info.summary.memPct) || 0) + "%"
                        color: LivePalette.color.onSurface
                        font.family: root.displayFont
                        font.pixelSize: 22
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "used"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: LivePalette.color.surfaceContainerHigh
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: 4
                        width: Math.max(8, parent.width * Math.min(1, ((root.info.summary && root.info.summary.memPct) || 0) / 100))
                        color: LivePalette.color.primary
                        Behavior on width { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle } }
                    }
                }
            }
        }

        // Storage Meter Card
        Rectangle {
            width: parent.tileWidth
            height: 112
            radius: 22
            color: LivePalette.color.surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: LivePalette.color.primaryContainer
                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 15
                            implicitHeight: 15
                            iconName: "folder-symbolic"
                            tint: LivePalette.color.primary
                        }
                    }

                    Text {
                        text: "ROOT /"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: Boolean(root.info.summary && root.info.summary.nvmeTemp)
                        radius: 999
                        color: LivePalette.color.surfaceContainerHigh
                        implicitWidth: nvmeTempTxt.implicitWidth + 12
                        implicitHeight: 20
                        Text {
                            id: nvmeTempTxt
                            anchors.centerIn: parent
                            text: (root.info.summary && root.info.summary.nvmeTemp) || ""
                            color: LivePalette.color.primary
                            font.family: root.monoFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ((root.info.summary && root.info.summary.diskPct) || 0) + "%"
                        color: LivePalette.color.onSurface
                        font.family: root.displayFont
                        font.pixelSize: 22
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (root.info.summary && root.info.summary.storage) || "—"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.monoFont
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: LivePalette.color.surfaceContainerHigh
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: 4
                        width: Math.max(8, parent.width * Math.min(1, ((root.info.summary && root.info.summary.diskPct) || 0) / 100))
                        color: LivePalette.color.primary
                        Behavior on width { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle } }
                    }
                }
            }
        }
    }

    // ================= 3. Connected Displays Topology Strip =================
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: (root.info.monitors || []).length > 0

        RowLayout {
            spacing: 8
            Layout.leftMargin: 4
            SymbolIcon {
                implicitWidth: 15
                implicitHeight: 15
                iconName: "video-display-symbolic"
                tint: LivePalette.color.primary
            }
            Text {
                text: "DISPLAYS"
                color: LivePalette.color.onSurfaceVariant
                font.family: root.monoFont
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 10
            readonly property int monCount: Math.max(1, (root.info.monitors || []).length)
            readonly property int cols: width > 520 ? Math.min(3, monCount) : width > 320 ? Math.min(2, monCount) : 1
            readonly property real cardW: Math.floor((width - (cols - 1) * spacing) / cols)

            Repeater {
                model: root.info.monitors || []
                delegate: Rectangle {
                    id: monCard
                    required property var modelData
                    width: parent.cardW
                    height: 76
                    radius: 20
                    color: modelData.focused
                        ? LivePalette.color.primaryContainer
                        : LivePalette.color.surfaceContainer

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: monCard.modelData.name
                                color: monCard.modelData.focused ? LivePalette.color.primary : LivePalette.color.onSurface
                                font.family: root.displayFont
                                font.pixelSize: 16
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                radius: 999
                                color: monCard.modelData.focused
                                    ? Qt.alpha(LivePalette.color.primary, 0.22)
                                    : LivePalette.color.surfaceContainerHigh
                                implicitWidth: hzTxt.implicitWidth + 12
                                implicitHeight: 20
                                Text {
                                    id: hzTxt
                                    anchors.centerIn: parent
                                    text: monCard.modelData.refresh
                                    color: LivePalette.color.primary
                                    font.family: root.monoFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Text {
                            text: monCard.modelData.res + "  ·  " + monCard.modelData.scale
                            color: LivePalette.color.onSurfaceVariant
                            font.family: root.monoFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // ================= 4. Detailed Spec Cards (Click row to copy) =================
    Repeater {
        model: root.info.sections || []
        delegate: ColumnLayout {
            id: sectionItem
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                spacing: 8
                Layout.leftMargin: 4
                SymbolIcon {
                    implicitWidth: 15
                    implicitHeight: 15
                    iconName: sectionItem.modelData.icon || "preferences-system-symbolic"
                    tint: LivePalette.color.primary
                }
                Text {
                    text: (sectionItem.modelData.title || "").toUpperCase()
                    color: LivePalette.color.onSurfaceVariant
                    font.family: root.monoFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 22
                color: LivePalette.color.surfaceContainer
                implicitHeight: rowsCol.implicitHeight + 16

                ColumnLayout {
                    id: rowsCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0

                    Repeater {
                        model: sectionItem.modelData.rows
                        delegate: ColumnLayout {
                            id: rowDelegate
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.max(40, rowContent.implicitHeight + 14)
                                radius: rowHover.pressed ? 16 : 12
                                color: rowHover.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.05) : "transparent"
                                scale: rowHover.pressed ? 0.985 : 1.0
                                Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyToClipboard(rowDelegate.modelData[1], rowDelegate.modelData[0] + " copied")
                                }

                                RowLayout {
                                    id: rowContent
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 16

                                    Text {
                                        Layout.preferredWidth: Math.min(156, Math.max(100, rowContent.width * 0.30))
                                        Layout.alignment: Qt.AlignVCenter
                                        text: rowDelegate.modelData[0]
                                        color: LivePalette.color.onSurfaceVariant
                                        font.family: root.monoFont
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        text: rowDelegate.modelData[1] || "Unavailable"
                                        color: LivePalette.color.onSurface
                                        font.family: root.monoFont
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                height: 1
                                visible: rowDelegate.index < (sectionItem.modelData.rows.length - 1)
                                color: Qt.alpha(LivePalette.color.onSurface, 0.05)
                            }
                        }
                    }
                }
            }
        }
    }
}
