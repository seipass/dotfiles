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
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            spacing: 0
            RollingClock {
                text: Qt.formatDateTime(root.panelDate, "HH:mm")
                fontPixelSize: 32
                fontFamily: Theme.font.display
                textColor: LivePalette.color.onSurface
            }
            ColumnLayout {
                Layout.leftMargin: 18
                spacing: 1
                Text { text: Qt.formatDateTime(root.panelDate, "dddd"); font.pixelSize: 14; font.weight: Font.Medium; color: LivePalette.color.onSurface }
                Text { text: Qt.formatDateTime(root.panelDate, "yyyy年 M月 d日"); font.pixelSize: 12; color: LivePalette.color.onSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            HeaderIconButton {
                Layout.alignment: Qt.AlignVCenter
                iconName: "emblem-system-symbolic"
                label: "Settings"
                onClicked: root.settingsRequested()
            }
        }

        // Weather & Volume Row (M3 Tonal Cards)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.minimumHeight: 46
            Layout.preferredHeight: 46
            Layout.maximumHeight: 46
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                radius: 23
                color: LivePalette.color.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 16
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: LivePalette.color.primaryContainer
                        SymbolIcon {
                            anchors.centerIn: parent
                            iconName: root.weatherTemp ? root.weatherIcon : "weather-severe-alert-symbolic"
                            implicitWidth: 18; implicitHeight: 18
                            tint: LivePalette.color.primary
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { Layout.fillWidth: true; text: root.weatherCity || "都市未設定"; font.pixelSize: 11; color: LivePalette.color.onSurfaceVariant; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: root.weatherDescription || (root.weatherCity ? "天気を取得できません" : "設定から都市を選択"); font.pixelSize: 12; font.weight: Font.Medium; color: LivePalette.color.onSurface; elide: Text.ElideRight }
                    }
                    Text { text: root.weatherTemp || "—"; font.family: Theme.font.display; font.pixelSize: 22; color: LivePalette.color.primary }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                radius: 23
                color: LivePalette.color.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 14
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 15
                        color: volMuteMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                        SymbolIcon {
                            anchors.centerIn: parent
                            implicitWidth: 16; implicitHeight: 16
                            iconName: root.volumeMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            tint: root.volumeMuted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                        }
                        MouseArea {
                            id: volMuteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        }
                    }
                    BarSlider {
                        id: volume
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 1; snapMode: Slider.SnapAlways
                        value: root.volumePercent
                        enabled: root.volumeAvailable
                        onMoved: Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)])
                    }
                    Text {
                        text: root.volumeMuted ? "MUTE" : root.volumePercent + "%"
                        color: root.volumeMuted ? LivePalette.color.onSurfaceVariant : LivePalette.color.primary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Media Card (M3 Extra Large)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 156
            radius: 24
            color: LivePalette.color.surfaceContainer
            clip: true

            Image {
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                opacity: 0.35
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(LivePalette.color.surface, 0.72)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackTitle || root.player.identity) : "再生中のメディアはありません"
                            color: LivePalette.color.onSurface
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.player ? (root.player.trackArtist || root.player.identity) : "メディアを再生すると表示されます"
                            color: LivePalette.color.onSurfaceVariant
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        spacing: 6
                        Repeater {
                            model: ["media-skip-backward-symbolic", "media-playback-start-symbolic", "media-skip-forward-symbolic"]
                            delegate: Rectangle {
                                id: mediaBtn
                                required property int index
                                required property string modelData
                                readonly property bool isPlay: index === 1
                                readonly property bool canAct: !!root.player && (index === 0 ? root.player.canGoPrevious : index === 1 ? root.player.canTogglePlaying : root.player.canGoNext)
                                width: isPlay ? 42 : 34
                                height: width
                                radius: isPlay
                                    ? ((root.player && root.player.isPlaying) ? width / 2 : 12)
                                    : width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: isPlay
                                    ? (canAct ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh)
                                    : LivePalette.color.surfaceContainerHigh
                                opacity: canAct ? 1 : 0.4
                                scale: mediaBtnMouse.pressed ? 0.92 : 1.0
                                Behavior on radius { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: mediaBtn.isPlay ? LivePalette.color.onPrimary : LivePalette.color.onSurface
                                    opacity: mediaBtnMouse.pressed ? 0.14 : mediaBtnMouse.containsMouse ? 0.08 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                                }
                                SymbolIcon {
                                    anchors.centerIn: parent
                                    implicitWidth: mediaBtn.isPlay ? 18 : 16
                                    implicitHeight: mediaBtn.isPlay ? 18 : 16
                                    iconName: mediaBtn.isPlay && root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : mediaBtn.modelData
                                    tint: mediaBtn.isPlay && mediaBtn.canAct ? LivePalette.color.onPrimary : LivePalette.color.onSurface
                                }
                                MouseArea {
                                    id: mediaBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: mediaBtn.canAct
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (mediaBtn.index === 0) root.player.previous();
                                        else if (mediaBtn.index === 1) root.player.togglePlaying();
                                        else root.player.next();
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                BarSlider {
                    id: seek
                    Layout.fillWidth: true
                    wavy: true
                    waveAnimated: !!(root.player && root.player.isPlaying && root.visible)
                    from: 0; to: root.player ? Math.max(1, root.player.length) : 1
                    value: root.player ? root.player.position : 0
                    enabled: root.player && root.player.canSeek && root.player.positionSupported
                    onMoved: root.player.position = value
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.timeString(root.player ? root.player.position : 0); color: LivePalette.color.onSurfaceVariant; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Text { text: root.timeString(root.player ? root.player.length : 0); color: LivePalette.color.onSurfaceVariant; font.pixelSize: 11 }
                }
            }
        }

        // Calendar & System Row (M3 Extra Large Cards)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 4
                Layout.fillHeight: true
                radius: 24
                color: LivePalette.color.surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDate(root.displayedMonth, "yyyy年 M月")
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: LivePalette.color.onSurface
                        }
                        Rectangle {
                            Layout.preferredWidth: 46; Layout.preferredHeight: 28; radius: 14
                            color: LivePalette.color.surfaceContainerHigh
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius; color: LivePalette.color.onSurface
                                opacity: todayMouse.pressed ? 0.12 : todayMouse.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                            }
                            Text { anchors.centerIn: parent; text: "今日"; font.pixelSize: 11; font.weight: Font.Medium; color: LivePalette.color.primary }
                            MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goToToday() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                            color: LivePalette.color.surfaceContainerHigh
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius; color: LivePalette.color.onSurface
                                opacity: previousMouse.pressed ? 0.12 : previousMouse.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                            }
                            Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 18; color: LivePalette.color.onSurface }
                            MouseArea { id: previousMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.changeMonth(-1) }
                        }
                        Rectangle {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                            color: LivePalette.color.surfaceContainerHigh
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius; color: LivePalette.color.onSurface
                                opacity: nextMouse.pressed ? 0.12 : nextMouse.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                            }
                            Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 18; color: LivePalette.color.onSurface }
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
                                font.pixelSize: 11
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
                                MaterialCookie {
                                    anchors.centerIn: parent
                                    visible: dayCell.today
                                    width: Math.min(30, dayCell.width, dayCell.height)
                                    height: width
                                    morph: dayMouse.containsMouse ? 1.0 : 0.0
                                    rotation: dayMouse.containsMouse ? 40 : 0
                                    fillColor: dayCell.selected ? LivePalette.color.primary : LivePalette.color.primaryContainer
                                    strokeColor: dayCell.selected ? "transparent" : LivePalette.color.primary
                                    strokeWidth: dayCell.selected ? 0 : 1.2
                                    Behavior on morph { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                                    Behavior on rotation { NumberAnimation { duration: Theme.motion.emphasized; easing.type: Easing.OutCubic } }
                                    Behavior on fillColor { ColorAnimation { duration: Theme.motion.fast } }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: !dayCell.today
                                    width: Math.min(28, dayCell.width, dayCell.height)
                                    height: width
                                    radius: dayCell.selected ? width / 2 : 9
                                    color: dayCell.selected ? LivePalette.color.primary : dayMouse.containsMouse ? LivePalette.color.surfaceContainerHigh : "transparent"
                                    Behavior on radius { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.date.getDate()
                                    font.pixelSize: 11
                                    font.weight: dayCell.selected || dayCell.today ? Font.DemiBold : Font.Normal
                                    color: dayCell.selected ? LivePalette.color.onPrimary : dayCell.inMonth ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
                                    opacity: dayCell.inMonth || dayCell.selected ? 1 : 0.55
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
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.fillHeight: true
                radius: 24
                color: LivePalette.color.surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text { text: "SYSTEM"; font.family: Theme.font.display; font.pixelSize: 15; color: LivePalette.color.onSurfaceVariant }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 6

                        WavyRing {
                            Layout.columnSpan: 2
                            Layout.alignment: Qt.AlignHCenter
                            label: "CPU"
                            percent: Math.max(0, Math.min(100, Number(root.resources.split("|")[0]) || 0))
                        }

                        WavyRing {
                            Layout.fillWidth: true
                            label: "RAM"
                            percent: Math.max(0, Math.min(100, Number(root.resources.split("|")[1]) || 0))
                        }

                        WavyRing {
                            Layout.fillWidth: true
                            label: "DISK"
                            percent: Math.max(0, Math.min(100, Number(root.resources.split("|")[2]) || 0))
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
