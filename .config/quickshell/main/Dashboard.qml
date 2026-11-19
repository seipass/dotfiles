import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "Theme.js" as Theme

Item {
    id: root
    property var panelDate
    property var player
    property int volumePercent
    property bool volumeMuted
    property bool volumeAvailable
    property string weatherCity: ""
    property string weatherTemp: ""
    property string weatherDescription: ""
    property string weatherIcon: "weather-clear-symbolic"
    property string resources: "—|—|—"
    property date selectedDate: new Date()
    property date displayedMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property int firstWeekday: Qt.locale().firstDayOfWeek % 7
    signal settingsRequested()

    function changeMonth(offset) {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + offset, 1);
    }
    function selectDay(date) {
        selectedDate = date;
        displayedMonth = new Date(date.getFullYear(), date.getMonth(), 1);
    }
    function goToToday() { selectDay(new Date()); }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    Process {
        id: metrics
        command: ["sh", "-c", "awk '/^cpu / {idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print idle,total}' /proc/stat; awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {if(t) printf \"%.0f\\n\",100*(t-a)/t}' /proc/meminfo; df -P / | awk 'NR==2 {gsub(/%/,\"\",$5); print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const cpu = lines[0].split(/\s+/).map(Number);
                if (root.lastTotal > 0 && cpu[1] > root.lastTotal)
                    root.cpuPercent = Math.round(100 * (1 - (cpu[0] - root.lastIdle) / (cpu[1] - root.lastTotal)));
                root.lastIdle = cpu[0]; root.lastTotal = cpu[1];
                root.resources = root.cpuPercent + "|" + (lines[1] || "—") + "|" + (lines[2] || "—");
            }
        }
    }
    property real lastIdle: 0
    property real lastTotal: 0
    property int cpuPercent: 0
    Component.onCompleted: metrics.running = true
    Timer { interval: 3000; repeat: true; running: root.visible; onTriggered: metrics.running = true }
    Timer { interval: 1000; repeat: true; running: root.visible && root.player && root.player.isPlaying; onTriggered: root.player.positionChanged() }
    function timeString(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2); }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            spacing: 0
            Text { text: Qt.formatDateTime(root.panelDate, "HH:mm"); font.pixelSize: 32; font.family: "Ndot 55"; color: LivePalette.color.onSurface }
            ColumnLayout {
                Layout.leftMargin: 18
                spacing: 1
                Text { text: Qt.formatDateTime(root.panelDate, "dddd"); font.pixelSize: 14; color: LivePalette.color.onSurface }
                Text { text: Qt.formatDateTime(root.panelDate, "yyyy年 M月 d日"); font.pixelSize: 12; color: LivePalette.color.onSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            SymbolIcon {
                iconName: "emblem-system-symbolic"
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignTop
                tint: LivePalette.color.onSurface
                MouseArea { anchors.fill: parent; anchors.margins: -9; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsRequested() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.minimumHeight: 38
            Layout.preferredHeight: 38
            Layout.maximumHeight: 38
            spacing: 10
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                radius: 18; color: LivePalette.color.surfaceContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14; anchors.rightMargin: 14
                    spacing: 10
                    SymbolIcon {
                        iconName: root.weatherTemp ? root.weatherIcon : "weather-severe-alert-symbolic"
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                        tint: LivePalette.color.onSurface
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { Layout.fillWidth: true; text: root.weatherCity || "都市未設定"; font.pixelSize: 11; color: LivePalette.color.onSurfaceVariant; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: root.weatherDescription || (root.weatherCity ? "天気を取得できません" : "設定から都市を選択"); font.pixelSize: 12; color: LivePalette.color.onSurface; elide: Text.ElideRight }
                    }
                    Text { text: root.weatherTemp || "—"; font.family: "Ndot 55"; font.pixelSize: 22; color: LivePalette.color.onSurface }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                radius: 18; color: LivePalette.color.surfaceContainer
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    SymbolIcon { iconName: root.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"; tint: LivePalette.color.onSurface
                        MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["wpctl","set-mute","@DEFAULT_AUDIO_SINK@","toggle"]) }
                    }
                    BarSlider {
                        id: volume; Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; snapMode: Slider.SnapAlways; value: root.volumePercent; enabled: root.volumeAvailable
                        onMoved: Quickshell.execDetached(["wpctl","set-volume","-l","1","@DEFAULT_AUDIO_SINK@",(value / 100).toFixed(2)])
                    }
                    Text { text: root.volumeMuted ? "MUTE" : root.volumePercent + "%"; color: LivePalette.color.onSurface; font.pixelSize: 12 }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 155; radius: 18; color: LivePalette.color.surfaceContainer; clip: true
            Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; opacity: 0.35 }
            Rectangle { anchors.fill: parent; color: "#a0191114" }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: root.player ? (root.player.trackTitle || root.player.identity) : "再生中のメディアはありません"; color: LivePalette.color.onSurface; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: root.player ? (root.player.trackArtist || root.player.identity) : "メディアを再生すると表示されます"; color: LivePalette.color.onSurfaceVariant; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    Repeater {
                        model: ["media-skip-backward-symbolic", "media-playback-start-symbolic", "media-skip-forward-symbolic"]
                        delegate: SymbolIcon {
                            required property int index
                            required property string modelData
                            iconName: index === 1 && root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : modelData
                            opacity: root.player && (index === 0 ? root.player.canGoPrevious : index === 1 ? root.player.canTogglePlaying : root.player.canGoNext) ? 1 : 0.3
                            MouseArea { anchors.fill: parent; anchors.margins: -5; enabled: parent.opacity === 1; onClicked: { if (index === 0) root.player.previous(); else if (index === 1) root.player.togglePlaying(); else root.player.next(); } }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                BarSlider {
                    id: seek; Layout.fillWidth: true; from: 0; to: root.player ? Math.max(1, root.player.length) : 1
                    value: root.player ? root.player.position : 0
                    enabled: root.player && root.player.canSeek && root.player.positionSupported
                    onMoved: root.player.position = value
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.timeString(root.player ? root.player.position : 0); color: LivePalette.color.onSurfaceVariant; font.pixelSize: 10 }
                    Item { Layout.fillWidth: true }
                    Text { text: root.timeString(root.player ? root.player.length : 0); color: LivePalette.color.onSurfaceVariant; font.pixelSize: 10 }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
            Rectangle {
                Layout.fillWidth: true; Layout.preferredWidth: 5; Layout.fillHeight: true; radius: 18; color: LivePalette.color.surfaceContainer
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 15; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDate(root.displayedMonth, "yyyy年 M月")
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: LivePalette.color.onSurface
                        }
                        Rectangle {
                            Layout.preferredWidth: 40; Layout.preferredHeight: 26; radius: 13
                            color: todayMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "今日"; font.pixelSize: 10; color: LivePalette.color.onSurfaceVariant }
                            MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goToToday() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                            color: previousMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 20; color: LivePalette.color.onSurface }
                            MouseArea { id: previousMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.changeMonth(-1) }
                        }
                        Rectangle {
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                            color: nextMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 20; color: LivePalette.color.onSurface }
                            MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.changeMonth(1) }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; columns: 7; rowSpacing: 2; columnSpacing: 2
                        Repeater {
                            model: 7
                            delegate: Text {
                                required property int index
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDate(new Date(2023, 0, 1 + (index + root.firstWeekday) % 7), "ddd")
                                color: LivePalette.color.onSurfaceVariant
                                font.pixelSize: 10
                            }
                        }
                        Repeater {
                            model: 42
                            delegate: Item {
                                id: dayCell
                                required property int index
                                readonly property int monthOffset: (new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth(), 1).getDay() - root.firstWeekday + 7) % 7
                                readonly property date date: new Date(root.displayedMonth.getFullYear(), root.displayedMonth.getMonth(), index - monthOffset + 1)
                                readonly property bool inMonth: date.getMonth() === root.displayedMonth.getMonth()
                                readonly property bool selected: root.sameDay(date, root.selectedDate)
                                readonly property bool today: root.sameDay(date, root.panelDate)
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(28, dayCell.width, dayCell.height)
                                    height: width
                                    radius: width / 2
                                    color: dayCell.selected ? LivePalette.color.primary : dayMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                                    border.width: dayCell.today && !dayCell.selected ? 1 : 0
                                    border.color: LivePalette.color.primary
                                    Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.date.getDate()
                                    font.pixelSize: 11
                                    color: dayCell.selected ? LivePalette.color.onPrimary : dayCell.inMonth ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
                                    opacity: dayCell.inMonth || dayCell.selected ? 1 : 0.6
                                }
                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectDay(dayCell.date)
                                    onWheel: function(wheel) {
                                        if (wheel.angleDelta.y !== 0) root.changeMonth(wheel.angleDelta.y > 0 ? -1 : 1);
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.selectedDate, "M月d日 dddd")
                        color: LivePalette.color.onSurfaceVariant
                        font.pixelSize: 10
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredWidth: 2; Layout.fillHeight: true; radius: 18; color: LivePalette.color.surfaceContainer
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 15; spacing: 9
                    Text { text: "SYSTEM"; font.family: "Ndot 55"; font.pixelSize: 15; color: LivePalette.color.onSurfaceVariant }
                    Repeater {
                        model: ["CPU", "RAM", "DISK"]
                        delegate: ColumnLayout {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true; spacing: 3
                            Text { text: modelData + "  " + root.resources.split("|")[index] + "%"; color: LivePalette.color.onSurface; font.pixelSize: 11 }
                            Rectangle { Layout.fillWidth: true; height: 4; radius: 2; color: LivePalette.color.outlineVariant
                                Rectangle { width: parent.width * Math.max(0, Math.min(100, Number(root.resources.split("|")[index]) || 0)) / 100; height: parent.height; radius: 2; color: LivePalette.color.primary }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
