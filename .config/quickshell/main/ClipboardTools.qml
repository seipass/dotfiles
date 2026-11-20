import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: root
    property var entries: []
    property string status: ""
    CheckBox {
        id: remember
        text: "Collect clipboard text while this page is open"
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
    Label {
        text: root.status || "Text stays in memory. Avoid collecting passwords."
        color: LivePalette.color.onSurfaceVariant
    }
    SettingsActionButton { text: "Clear"; onClicked: root.entries = [] }
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: root.entries
        delegate: SettingsActionButton {
            required property string modelData
            width: ListView.view.width
            text: modelData.replace(/\s+/g, " ").slice(0, 42)
            onClicked: {
                copier.text = modelData;
                copier.selectAll();
                copier.copy();
                copier.text = "";
            }
        }
    }
}
