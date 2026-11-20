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
    property double stopwatchStarted: 0
    property int stopwatchElapsed: 0
    readonly property int stopwatchSeconds: stopwatchElapsed + (stopwatchStarted ? Math.max(0, Math.floor((now - stopwatchStarted) / 1000)) : 0)
    function clockText(seconds) {
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
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
        running: root.started > 0 || root.stopwatchStarted > 0
        onTriggered: {
            root.now = Date.now();
            if (root.started && root.seconds === 0) {
                root.started = 0;
                root.remaining = 0;
                Quickshell.execDetached(["notify-send", "Timer finished", "Time for a break."]);
            }
        }
    }
    Label {
        text: root.clockText(root.seconds)
        font.pixelSize: 28
        color: LivePalette.color.onSurface
    }
    RowLayout {
        SettingsActionButton { text: "Focus · 25 min"; onClicked: root.start(25) }
        SettingsActionButton { text: "Break · 5 min"; onClicked: root.start(5) }
        SettingsActionButton { text: "Stop"; onClicked: { root.started = 0; root.remaining = 0; } }
    }
    RowLayout {
        Label {
            Layout.fillWidth: true
            text: "Stopwatch · " + root.clockText(root.stopwatchSeconds)
            color: LivePalette.color.onSurface
        }
        SettingsActionButton {
            text: root.stopwatchStarted ? "Pause" : "Start"
            onClicked: {
                root.now = Date.now();
                if (root.stopwatchStarted) {
                    root.stopwatchElapsed = root.stopwatchSeconds;
                    root.stopwatchStarted = 0;
                } else root.stopwatchStarted = root.now;
            }
        }
        SettingsActionButton {
            text: "Reset"
            onClicked: { root.stopwatchStarted = 0; root.stopwatchElapsed = 0; }
        }
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
