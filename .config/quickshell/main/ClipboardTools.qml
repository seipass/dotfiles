import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

ColumnLayout {
    id: root
    property var shellState
    spacing: 10
    property int copiedIndex: -1
    readonly property var entries: root.shellState ? (root.shellState.clipboardHistory || []) : []

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

    Timer {
        id: copiedReset
        interval: 1200
        onTriggered: root.copiedIndex = -1
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "HISTORY (" + root.entries.length + ")"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: LivePalette.color.onSurfaceVariant
        }
        Item { Layout.fillWidth: true }
        SettingsActionButton {
            visible: root.entries.length > 0
            implicitHeight: 32
            horizontalPadding: 14
            text: "Clear"
            onClicked: if (root.shellState) root.shellState.clearClipboard()
        }
    }

    Text {
        Layout.fillWidth: true
        text: "テキスト・画像に対応（Win + V でカーソル付近に表示）"
        font.pixelSize: 11
        color: LivePalette.color.onSurfaceVariant
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: root.entries
        ScrollBar.vertical: ScrollBar {}
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.fast; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle }
        }

        delegate: Rectangle {
            id: entryCard
            required property var modelData
            required property int index
            readonly property bool isImage: modelData.type === "image"
            width: ListView.view.width - 4
            implicitHeight: isImage ? 80 : 54
            radius: clipMouse.pressed ? 14 : (root.copiedIndex === index ? 24 : 18)
            color: root.copiedIndex === index ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
            scale: clipMouse.pressed ? 0.96 : 1.0
            Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
            Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: LivePalette.color.onSurface
                opacity: clipMouse.pressed ? 0.12 : clipMouse.containsMouse ? 0.07 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
            }

            // Text Row
            RowLayout {
                visible: !entryCard.isImage
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: (entryCard.modelData.text || "").replace(/\s+/g, " ")
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                    color: LivePalette.color.onSurface
                    elide: Text.ElideRight
                }

                Text {
                    text: root.copiedIndex === entryCard.index ? "Copied" : (entryCard.modelData.time || "")
                    font.pixelSize: 11
                    font.weight: root.copiedIndex === entryCard.index ? Font.DemiBold : Font.Normal
                    color: root.copiedIndex === entryCard.index ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                }
            }

            // Image Row
            RowLayout {
                visible: entryCard.isImage
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 64
                    radius: 12
                    color: LivePalette.color.surface
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: entryCard.isImage && entryCard.modelData.path ? ("file://" + entryCard.modelData.path) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    RowLayout {
                        spacing: 6
                        Text {
                            text: root.formatMime(entryCard.modelData.mime)
                            font.family: "Ioskeley Mono Term"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: LivePalette.color.primary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.copiedIndex === entryCard.index ? "Copied" : (entryCard.modelData.time || "")
                            font.pixelSize: 11
                            font.weight: root.copiedIndex === entryCard.index ? Font.DemiBold : Font.Normal
                            color: root.copiedIndex === entryCard.index ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: ((entryCard.modelData.width > 0 && entryCard.modelData.height > 0)
                            ? (entryCard.modelData.width + " × " + entryCard.modelData.height + " · ")
                            : "") + root.formatSize(entryCard.modelData.size)
                        font.family: "Ioskeley Mono Term"
                        font.pixelSize: 11
                        color: LivePalette.color.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.shellState) root.shellState.copyClipboardEntry(entryCard.modelData);
                    root.copiedIndex = entryCard.index;
                    copiedReset.restart();
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: parent.count === 0
            text: "コピーしたテキスト・画像が自動で記録されます"
            color: LivePalette.color.onSurfaceVariant
        }
    }
}
