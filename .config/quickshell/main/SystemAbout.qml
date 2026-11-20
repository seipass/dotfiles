import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Theme.js" as Theme

ColumnLayout {
    id: root
    required property string fontFamily
    property var info: ({ summary: {}, sections: [] })
    property bool failed: false
    spacing: 20

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

    // ================= Hero Banner Card =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: heroLayout.implicitHeight + 36
        radius: 18
        color: LivePalette.color.surfaceContainer
        border.color: Qt.alpha(LivePalette.color.onSurface, 0.08)
        border.width: 1
        clip: true

        // Ambient subtle background gradient
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 260
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(LivePalette.color.primary, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            id: heroLayout
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            // OS Distro Logo Container
            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: Qt.alpha(LivePalette.color.primary, 0.14)
                border.color: Qt.alpha(LivePalette.color.primary, 0.3)
                border.width: 1.5

                Image {
                    id: distroLogoImg
                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    fillMode: Image.PreserveAspectFit
                    source: (root.info.summary && root.info.summary.logoPath) || ""
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready
                }

                SymbolIcon {
                    anchors.centerIn: parent
                    implicitWidth: 32
                    implicitHeight: 32
                    iconName: "distributor-logo"
                    tint: LivePalette.color.primary
                    visible: !distroLogoImg.visible
                }
            }

            // Hero Text
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Text {
                        text: (root.info.summary && root.info.summary.osPretty) || "Linux Workstation"
                        color: LivePalette.color.onSurface
                        font.family: root.fontFamily
                        font.pixelSize: 21
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        radius: 6
                        color: Qt.alpha(LivePalette.color.primary, 0.18)
                        border.color: Qt.alpha(LivePalette.color.primary, 0.3)
                        border.width: 1
                        implicitWidth: archText.implicitWidth + 12
                        implicitHeight: 22

                        Text {
                            id: archText
                            anchors.centerIn: parent
                            text: (root.info.summary && root.info.summary.arch) || "x86_64"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: LivePalette.color.primary
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    text: {
                        const s = root.info.summary;
                        if (!s || !s.hostname) return "Quickshell Desktop Experience";
                        return s.hostname + " · Up " + (s.uptime || "just now") + " · Kernel " + (s.kernel || "");
                    }
                    color: LivePalette.color.onSurfaceVariant
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: (root.info.summary && root.info.summary.cpu) || ""
                    color: Qt.alpha(LivePalette.color.onSurfaceVariant, 0.8)
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Refresh action
            Button {
                id: heroRefreshBtn
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 38
                implicitHeight: 38
                hoverEnabled: true
                background: Rectangle {
                    radius: 12
                    color: heroRefreshBtn.down ? Qt.alpha(LivePalette.color.onSurface, 0.1) :
                           heroRefreshBtn.hovered ? Qt.alpha(LivePalette.color.onSurface, 0.06) : "transparent"
                    border.color: heroRefreshBtn.hovered ? Qt.alpha(LivePalette.color.onSurface, 0.12) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                contentItem: SymbolIcon {
                    anchors.centerIn: parent
                    implicitWidth: 17
                    implicitHeight: 17
                    iconName: "view-refresh-symbolic"
                    tint: heroRefreshBtn.hovered ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                }
                onClicked: collector.running = true
            }
        }
    }

    // ================= Hardware KPI Glance Tiles (Responsive Flow/Layout) =================
    Flow {
        Layout.fillWidth: true
        spacing: 12

        readonly property int colCount: width > 580 ? 3 : width > 360 ? 2 : 1
        readonly property real tileWidth: Math.floor((width - (colCount - 1) * spacing) / colCount)

        // CPU Tile
        Rectangle {
            width: parent.tileWidth
            height: 72
            radius: 14
            color: LivePalette.color.surfaceContainer
            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
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
                        iconName: "cpu-symbolic"
                        tint: LivePalette.color.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Processor"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: (root.info.summary && root.info.summary.cpuCores) || "Multi-core"
                        color: LivePalette.color.onSurface
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // RAM Tile
        Rectangle {
            width: parent.tileWidth
            height: 72
            radius: 14
            color: LivePalette.color.surfaceContainer
            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
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
                        iconName: "drive-harddisk-symbolic"
                        tint: LivePalette.color.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Memory (RAM)"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: (root.info.summary && root.info.summary.memory) || "—"
                        color: LivePalette.color.onSurface
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Storage Tile
        Rectangle {
            width: parent.tileWidth
            height: 72
            radius: 14
            color: LivePalette.color.surfaceContainer
            border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
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
                        iconName: "folder-symbolic"
                        tint: LivePalette.color.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Root Storage"
                        color: LivePalette.color.onSurfaceVariant
                        font.family: root.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: (root.info.summary && root.info.summary.storage) || "—"
                        color: LivePalette.color.onSurface
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ================= Sections Detail Cards =================
    Repeater {
        model: root.info.sections || []
        delegate: ColumnLayout {
            id: sectionItem
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 8

            // Section Header
            RowLayout {
                spacing: 8
                Layout.leftMargin: 4
                SymbolIcon {
                    implicitWidth: 16
                    implicitHeight: 16
                    iconName: sectionItem.modelData.icon || "preferences-system-symbolic"
                    tint: LivePalette.color.primary
                }
                Text {
                    text: sectionItem.modelData.title
                    color: LivePalette.color.onSurface
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }

            // Card Container
            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: LivePalette.color.surfaceContainer
                border.color: Qt.alpha(LivePalette.color.onSurface, 0.07)
                border.width: 1
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
                                implicitHeight: Math.max(42, rowContent.implicitHeight + 16)
                                radius: 8
                                color: rowHover.containsMouse ? Qt.alpha(LivePalette.color.onSurface, 0.04) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    id: rowContent
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 16

                                    Text {
                                        Layout.preferredWidth: Math.min(160, Math.max(100, rowContent.width * 0.32))
                                        Layout.alignment: Qt.AlignVCenter
                                        text: rowDelegate.modelData[0]
                                        color: LivePalette.color.onSurfaceVariant
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        text: rowDelegate.modelData[1] || "Unavailable"
                                        color: LivePalette.color.onSurface
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            // Divider between rows
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                height: 1
                                visible: rowDelegate.index < (sectionItem.modelData.rows.length - 1)
                                color: Qt.alpha(LivePalette.color.onSurface, 0.04)
                            }
                        }
                    }
                }
            }
        }
    }
}
