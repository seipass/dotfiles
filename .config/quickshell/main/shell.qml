//@ pragma IconTheme Adwaita
//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import QtQuick

ShellRoot {
    id: root
    property var notificationHistory: []
    property int unreadNotifications: 0
    property bool doNotDisturb: false
    readonly property bool desktopClock: settings.desktopClock
    function setDesktopClock(enabled) { settings.desktopClock = enabled; }
    property alias showTray: settings.showTray
    property alias showTaskbar: settings.showTaskbar
    readonly property string wallpaperPath: settings.wallpaper
    function setWallpaper(path) { settings.setWallpaper(path); }
    function openSettings(screen) { settings.open(screen); }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool volumeMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool volumeAvailable: !!(sink && sink.audio)
    property string networkLabel: "OFF"
    property string weatherTemp: ""
    property string weatherDescription: ""
    property var notificationScreen: null
    property bool selectingNotificationScreen: false
    readonly property string weatherIcon: {
        const condition = weatherDescription.toLowerCase();
        if (/thunder|storm/.test(condition)) return "weather-storm-symbolic";
        if (/snow|sleet|blizzard|ice/.test(condition)) return "weather-snow-symbolic";
        if (/rain|drizzle|shower/.test(condition)) return "weather-showers-symbolic";
        if (/fog|mist/.test(condition)) return "weather-fog-symbolic";
        if (/overcast|cloudy/.test(condition)) return "weather-overcast-symbolic";
        if (/cloud/.test(condition)) return "weather-few-clouds-symbolic";
        return "weather-clear-symbolic";
    }

    function refreshWeather() {
        weatherProcess.running = false;
        weatherTemp = "";
        weatherDescription = "";
        if (settings.weatherCity.trim()) weatherProcess.running = true;
    }

    Launcher {
        id: launcher
        taskbarController: sharedTaskbar
    }

    TaskbarController { id: sharedTaskbar }
    IpcHandler {
        target: "taskbarStatus"
        function entries(): string { return JSON.stringify(sharedTaskbar.entries.map(e => ({id: e.id, count: e.windows.length}))); }
    }
    SettingsWindow {
        id: settings
        onWeatherCityChanged: root.refreshWeather()
    }

    Variants {
        model: Quickshell.screens
        Wallpaper {
            required property var modelData
            screen: modelData
            imagePath: settings.wallpaper
            showClock: settings.desktopClock
            clockDate: clock.date
        }
    }

    Process {
        id: weatherProcess
        command: ["curl", "-fsSL", "--max-time", "8", "https://wttr.in/" + encodeURIComponent(settings.weatherCity.trim()) + "?format=%25t%7C%25C"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                root.weatherTemp = parts.length > 1 ? parts[0].trim() : "";
                root.weatherDescription = parts.length > 1 ? parts.slice(1).join("|").trim() : "";
            }
        }
    }
    Component.onCompleted: root.refreshWeather()
    Timer { interval: 1800000; repeat: true; running: settings.weatherCity.trim().length > 0; onTriggered: root.refreshWeather() }
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        onNotification: function(notification) {
            root.notificationHistory = [{
                app: notification.appName || "Notification",
                title: notification.summary,
                body: notification.body,
                time: Qt.formatTime(new Date(), "HH:mm")
            }, ...root.notificationHistory].slice(0, 50);
            root.unreadNotifications++;
            if (root.doNotDisturb) {
                notification.tracked = true;
                notification.dismiss();
                return;
            }
            if (trackedNotifications.values.length === 0 && !root.selectingNotificationScreen) {
                root.selectingNotificationScreen = true;
                notificationMonitorProcess.running = true;
            }
            notification.tracked = true;
        }
    }

    Process {
        id: notificationMonitorProcess
        command: ["python3", "-c",
            "import json,subprocess\n"
            + "def get(*a): return json.loads(subprocess.check_output(a, timeout=2))\n"
            + "p=get('hyprctl','cursorpos','-j'); ms=get('hyprctl','monitors','-j')\n"
            + "for m in ms:\n"
            + " w,h=m['width'],m['height']\n"
            + " if m.get('transform',0)%2: w,h=h,w\n"
            + " w/=m['scale']; h/=m['scale']\n"
            + " if m['x']<=p['x']<m['x']+w and m['y']<=p['y']<m['y']+h:\n"
            + "  print(m['name']); break\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim();
                const match = Quickshell.screens.find(screen => screen.name === name);
                if (match) root.notificationScreen = match;
            }
        }
        onExited: root.selectingNotificationScreen = false
    }

    Variants {
        model: Quickshell.screens
        VolumeOsd {
            required property var modelData
            screen: modelData
            percent: root.volumePercent
            muted: root.volumeMuted
            available: root.volumeAvailable
        }
    }

    NotificationPopup {
        notifications: notificationServer.trackedNotifications
        screen: root.notificationScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null)
        selectingScreen: root.selectingNotificationScreen
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    IpcHandler {
        target: "audioStatus"
        function status(): string {
            return root.volumePercent + "|" + root.volumeMuted + "|" + (root.sink && root.sink.audio ? root.sink.audio.volume : -1);
        }
    }
    IpcHandler {
        target: "displayInfo"
        function screens(): string {
            return JSON.stringify(Quickshell.screens.map(screen => screen.name));
        }
    }

    Process {
        id: networkProcess
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split(/\r?\n/);
                let connected = "";
                for (let i = 0; i < lines.length; ++i) {
                    if (/^(wifi|ethernet):connected$/.test(lines[i])) {
                        connected = lines[i].split(":")[0];
                        break;
                    }
                }

                root.networkLabel = connected === "wifi"
                    ? "WIFI" : connected === "ethernet" ? "ETH" : "OFF";
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: networkProcess.running = true
    }

    Variants {
        model: Quickshell.screens

        ShellFrame {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        VerticalBar {
            required property var modelData

            screen: modelData
            shellState: root
            launcherController: launcher
            taskbarController: sharedTaskbar
            panelDate: clock.date
            volumePercent: root.volumePercent
            volumeMuted: root.volumeMuted
            volumeAvailable: root.volumeAvailable
        }
    }

    Variants {
        model: Quickshell.screens

        DynamicIsland {
            required property var modelData

            screen: modelData
            panelDate: clock.date
            volumePercent: root.volumePercent
            volumeMuted: root.volumeMuted
            volumeAvailable: root.volumeAvailable
            networkLabel: root.networkLabel
            weatherTemp: root.weatherTemp
            weatherDescription: root.weatherDescription
            weatherIcon: root.weatherIcon
            settingsController: settings
        }
    }
}
