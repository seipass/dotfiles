import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    required property string fontFamily
    property var sections: []
    property bool failed: false
    spacing: 12

    onVisibleChanged: if (visible) collector.running = true
    Component.onCompleted: if (visible) collector.running = true

    Process {
        id: collector
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/system-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.sections = JSON.parse(text); root.failed = false; }
                catch (_) { root.failed = true; }
            }
        }
        onExited: code => { if (code !== 0) root.failed = true; }
    }

    Text {
        visible: root.failed || root.sections.length === 0
        text: root.failed ? "System information could not be loaded." : "Reading system information…"
        color: LivePalette.color.onSurfaceVariant
        font.family: root.fontFamily
    }

    Repeater {
        model: root.sections
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + 32
            radius: 20
            color: LivePalette.color.surfaceContainer

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                Text {
                    text: modelData.title
                    color: LivePalette.color.primary
                    font.family: root.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: modelData.rows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.preferredWidth: 116
                            Layout.alignment: Qt.AlignTop
                            text: modelData[0]
                            color: LivePalette.color.onSurfaceVariant
                            font.family: root.fontFamily
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData[1] || "Unavailable"
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: LivePalette.color.onSurface
                            font.family: root.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
