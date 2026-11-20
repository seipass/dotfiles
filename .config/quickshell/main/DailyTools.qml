import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell

ColumnLayout {
    id: root
    property double started: 0
    property double remaining: 0
    property double now: Date.now()
    readonly property int seconds: Math.max(0, Math.ceil((remaining + (started ? started - now : 0)) / 1000))
    function start(minutes) {
        remaining = minutes * 60000;
        now = Date.now();
        started = now;
    }
    Settings {
        id: saved
        location: "file://" + Quickshell.env("HOME") + "/.config/quickshell/main/daily-tools.ini"
        category: "DailyTools"
        property string notes: ""
    }
    Timer {
        interval: 250
        repeat: true
        running: root.started > 0
        onTriggered: {
            root.now = Date.now();
            if (root.seconds === 0) {
                root.started = 0;
                root.remaining = 0;
                Quickshell.execDetached(["notify-send", "Timer finished", "Time for a break."]);
            }
        }
    }
    Label {
        text: Math.floor(root.seconds / 60) + ":" + String(root.seconds % 60).padStart(2, "0")
        font.pixelSize: 28
        color: LivePalette.color.onSurface
    }
    RowLayout {
        SettingsActionButton { text: "Focus · 25 min"; onClicked: root.start(25) }
        SettingsActionButton { text: "Break · 5 min"; onClicked: root.start(5) }
        SettingsActionButton { text: "Stop"; onClicked: { root.started = 0; root.remaining = 0; } }
    }
    Label { text: "Notes"; color: LivePalette.color.onSurface }
    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        TextArea {
            text: saved.notes
            onTextChanged: if (text !== saved.notes) saved.notes = text
            placeholderText: "Write a note…"
            wrapMode: TextEdit.Wrap
        }
    }
}
