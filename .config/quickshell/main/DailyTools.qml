import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import "Theme.js" as Theme

ColumnLayout {
    id: root
    spacing: 12
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

    // Focus Timer Card
    Rectangle {
        Layout.fillWidth: true
        radius: root.started > 0 ? 28 : 20
        color: root.started > 0 ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
        implicitHeight: timerCol.implicitHeight + 28
        Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

        ColumnLayout {
            id: timerCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "FOCUS TIMER"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    color: LivePalette.color.onSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.clockText(root.seconds)
                    font.family: Theme.font.display
                    font.pixelSize: 28
                    color: root.started > 0 ? LivePalette.color.primary : LivePalette.color.onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                SettingsActionButton {
                    Layout.fillWidth: true
                    primary: root.started === 0
                    text: "25m Focus"
                    onClicked: root.start(25)
                }
                SettingsActionButton {
                    Layout.fillWidth: true
                    text: "5m Break"
                    onClicked: root.start(5)
                }
                SettingsActionButton {
                    text: "Stop"
                    enabled: root.started > 0 || root.seconds > 0
                    onClicked: { root.started = 0; root.remaining = 0; }
                }
            }
        }
    }

    // Stopwatch Card
    Rectangle {
        Layout.fillWidth: true
        radius: root.stopwatchStarted > 0 ? 28 : 20
        color: root.stopwatchStarted > 0 ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
        implicitHeight: swRow.implicitHeight + 28
        Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

        RowLayout {
            id: swRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "STOPWATCH"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    color: LivePalette.color.onSurfaceVariant
                }
                Text {
                    text: root.clockText(root.stopwatchSeconds)
                    font.family: Theme.font.display
                    font.pixelSize: 22
                    color: root.stopwatchStarted > 0 ? LivePalette.color.primary : LivePalette.color.onSurface
                }
            }

            SettingsActionButton {
                primary: !root.stopwatchStarted
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
                enabled: root.stopwatchSeconds > 0 || root.stopwatchStarted > 0
                onClicked: { root.stopwatchStarted = 0; root.stopwatchElapsed = 0; }
            }
        }
    }

    // Scratchpad Notes
    Text {
        Layout.fillWidth: true
        text: "SCRATCHPAD NOTES"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        color: LivePalette.color.onSurfaceVariant
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: LivePalette.color.surfaceContainer
        border.width: 1
        border.color: noteArea.activeFocus ? LivePalette.color.primary : Qt.alpha(LivePalette.color.onSurface, 0.07)
        Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 6
            clip: true

            TextArea {
                id: noteArea
                text: saved.notes
                onTextChanged: if (text !== saved.notes) saved.notes = text
                placeholderText: "Jot down quick notes…"
                wrapMode: TextEdit.Wrap
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                color: LivePalette.color.onSurface
                placeholderTextColor: LivePalette.color.onSurfaceVariant
                background: Item {}
            }
        }
    }
}
