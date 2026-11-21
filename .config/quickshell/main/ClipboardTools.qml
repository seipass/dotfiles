import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "Theme.js" as Theme

ColumnLayout {
    id: root
    spacing: 10
    property var entries: []
    property string status: ""
    property int copiedIndex: -1

    Timer {
        id: copiedReset
        interval: 1200
        onTriggered: root.copiedIndex = -1
    }

    // Collect Toggle Card
    ToggleRow {
        Layout.fillWidth: true
        iconName: "edit-paste-symbolic"
        title: "Collect Clipboard"
        subtitle: root.status || "Kept in memory while open"
        checked: remember.checked
        onToggled: {
            remember.checked = !remember.checked;
            if (remember.checked) reader.running = true;
        }
    }

    CheckBox {
        id: remember
        visible: false
        onToggled: if (checked) reader.running = true
    }

    Process {
        id: reader
        command: ["sh", "-c", "exec wl-paste --no-newline --type text"]
        onExited: code => {
            if (code === 127) root.status = "Install wl-clipboard to read the clipboard.";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text;
                if (root.visible && remember.checked && value && value.length <= 16384
                    && root.entries[0] !== value)
                    root.entries = [value, ...root.entries.filter(entry => entry !== value)].slice(0, 20);
            }
        }
    }
    Timer {
        interval: 850
        repeat: true
        running: root.visible && remember.checked && !root.status
        onTriggered: reader.running = true
    }
    TextEdit { id: copier; visible: false }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "SNIPPETS (" + root.entries.length + ")"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: LivePalette.color.onSurfaceVariant
        }
        Item { Layout.fillWidth: true }
        SettingsActionButton {
            visible: root.entries.length > 0
            implicitHeight: 30
            horizontalPadding: 12
            text: "Clear"
            onClicked: root.entries = []
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: root.entries
        ScrollBar.vertical: ScrollBar {}

        delegate: Rectangle {
            required property string modelData
            required property int index
            width: ListView.view.width - 4
            implicitHeight: 52
            radius: 18
            color: root.copiedIndex === index ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: LivePalette.color.onSurface
                opacity: clipMouse.pressed ? 0.12 : clipMouse.containsMouse ? 0.07 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: modelData.replace(/\s+/g, " ")
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                    color: LivePalette.color.onSurface
                    elide: Text.ElideRight
                }

                Text {
                    visible: root.copiedIndex === index
                    text: "Copied"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: LivePalette.color.primary
                }
            }

            MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    copier.text = modelData;
                    copier.selectAll();
                    copier.copy();
                    copier.text = "";
                    root.copiedIndex = index;
                    copiedReset.restart();
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: parent.count === 0
            text: remember.checked ? "Copy text to see it appear here" : "Enable collection above to track copies"
            color: LivePalette.color.onSurfaceVariant
        }
    }
}
