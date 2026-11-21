//@ pragma IconTheme Adwaita
//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import QtQuick

ShellRoot {
    id: root
    FontLoader { id: headingFont; source: "fonts/Doto.ttf" }
    FontLoader { id: mainFont; source: "fonts/GoogleSansFlex.ttf" }
    property var codexQuota: ({})
    property alias quotaProvider: settings.quotaProvider
    function refreshQuota() {
        if (!quotaReader.running) quotaReader.running = true;
    }
    Process {
        id: quotaReader
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/ai-usage.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.codexQuota = JSON.parse(text); }
                catch (_) { root.codexQuota = {}; }
            }
        }
    }
    Timer {
        interval: Math.max(15, settings.quotaInterval || 60) * 1000
        running: true
        repeat: true
        onTriggered: quotaReader.running = true
    }
    Connections {
        target: settings
        function onQuotaIntervalChanged() { quotaReader.running = true; }
    }
    property var notificationHistory: []
    property int unreadNotifications: 0
    property bool doNotDisturb: false
    property var clipboardHistory: []
    Process {
        id: clipboardDaemon
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/clipboard-daemon.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const entry = JSON.parse(line);
                    root.recordClipboardEntry(entry);
                } catch (_) {}
            }
        }
        onExited: clipboardRestartTimer.restart()
    }
    Timer {
        id: clipboardRestartTimer
        interval: 2000
        onTriggered: clipboardDaemon.running = true
    }
    function recordClipboardEntry(entry) {
        if (!entry || !entry.type) return;
        if (entry.type === "text") {
            if (typeof entry.text !== "string" || !entry.text || entry.text.length > 65536) return;
            const key = entry.id || entry.text;
            const norm = {
                type: "text",
                id: key,
                text: entry.text,
                time: entry.time || Qt.formatTime(new Date(), "HH:mm")
            };
            if (clipboardHistory.length > 0 && clipboardHistory[0].type === "text" && clipboardHistory[0].text === norm.text) return;
            clipboardHistory = [norm, ...clipboardHistory.filter(item => !(item.type === "text" && item.text === norm.text))].slice(0, 40);
        } else if (entry.type === "image") {
            if (!entry.path) return;
            const key = entry.id || entry.path;
            const norm = {
                type: "image",
                id: key,
                path: entry.path,
                mime: entry.mime || "image/png",
                width: entry.width || 0,
                height: entry.height || 0,
                size: entry.size || 0,
                time: entry.time || Qt.formatTime(new Date(), "HH:mm")
            };
            if (clipboardHistory.length > 0 && clipboardHistory[0].type === "image" && clipboardHistory[0].id === norm.id) return;
            clipboardHistory = [norm, ...clipboardHistory.filter(item => !(item.type === "image" && item.id === norm.id))].slice(0, 40);
        }
    }
    function copyClipboardEntry(entry) {
        if (!entry) return;
        if (typeof entry === "string") {
            copyToClipboard(entry);
            return;
        }
        if (entry.type === "image" && entry.path) {
            if (clipboardDaemon.running) {
                clipboardDaemon.write(JSON.stringify({ cmd: "copy_image", path: entry.path, mime: entry.mime || "image/png" }) + "\n");
            }
            recordClipboardEntry({
                type: "image",
                id: entry.id,
                path: entry.path,
                mime: entry.mime,
                width: entry.width,
                height: entry.height,
                size: entry.size,
                time: Qt.formatTime(new Date(), "HH:mm")
            });
        } else if (entry.text) {
            copyToClipboard(entry.text);
        }
    }
    function copyToClipboard(value) {
        if (typeof value !== "string" || !value) return;
        if (clipboardDaemon.running) {
            clipboardDaemon.write(JSON.stringify({ cmd: "copy_text", text: value }) + "\n");
        } else {
            Quickshell.clipboardText = value;
        }
        recordClipboardEntry({ type: "text", text: value, time: Qt.formatTime(new Date(), "HH:mm") });
    }
    function clearClipboard() {
        clipboardHistory = [];
        if (clipboardDaemon.running) {
            clipboardDaemon.write(JSON.stringify({ cmd: "clear" }) + "\n");
        }
    }
    readonly property alias settingsController: settings
    readonly property bool desktopClock: settings.desktopClock
    function setDesktopClock(enabled) { settings.desktopClock = enabled; }
    property alias showTray: settings.showTray
    property alias showTaskbar: settings.showTaskbar
    readonly property string wallpaperPath: settings.wallpaper
    function setWallpaper(path) { settings.setWallpaper(path); }
    function openSettings(screen) { settings.open(screen); }
    function openSettingsPage(screen, pageIndex) { settings.page = pageIndex; settings.open(screen); }
    function openSystemInfo(screen) { openSettingsPage(screen, 4); }

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

    ClipboardPopup {
        id: clipboardPopup
        shellState: root
    }

    TaskbarController { id: sharedTaskbar }
    IpcHandler {
        target: "taskbarStatus"
        function entries(): string { return JSON.stringify(sharedTaskbar.entries.map(e => ({id: e.id, count: e.windows.length}))); }
    }
    SettingsWindow {
        id: settings
        volumePercent: root.volumePercent
        volumeMuted: root.volumeMuted
        volumeAvailable: root.volumeAvailable
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

    property var earthquakeHistory: []
    readonly property var earthquakeInfo: earthquakeHistory.length > 0 ? earthquakeHistory[0] : ({})
    property bool earthquakeLoading: false
    property bool earthquakeLive: false
    function refreshEarthquake() {
        if (earthquakeProcess.running) return;
        earthquakeLoading = true;
        earthquakeProcess.running = true;
    }
    Process {
        id: earthquakeWsProcess
        running: settings.islandDisplay === "earthquake" && settings.earthquakeInterval === 0
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/main/earthquake-ws.py"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const msg = JSON.parse(line);
                    if (msg.type === "connected") {
                        root.earthquakeLive = true;
                    } else if (msg.type === "snapshot" && Array.isArray(msg.items)) {
                        root.earthquakeHistory = msg.items;
                        root.earthquakeLoading = false;
                    } else if (msg.type === "event" && msg.item) {
                        const next = [msg.item, ...root.earthquakeHistory.filter(e =>
                            !(e.rawTime === msg.item.rawTime && e.place === msg.item.place))];
                        next.sort((a, b) => b.rawTime.localeCompare(a.rawTime));
                        root.earthquakeHistory = next.slice(0, 8);
                    }
                } catch (_) {}
            }
        }
        onExited: root.earthquakeLive = false
    }
    Process {
        id: earthquakeProcess
        command: ["curl", "-fsSL", "--max-time", "6", "https://api.p2pquake.net/v2/history?codes=551&limit=8"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim());
                    if (Array.isArray(data)) {
                        root.earthquakeHistory = data.filter(item => item && item.earthquake).map(item => {
                            const eq = item.earthquake;
                            const hypo = eq.hypocenter || {};
                            const rawTime = eq.time || "";
                            const hmMatch = rawTime.match(/(\d{2}:\d{2})/);
                            const fullMatch = rawTime.match(/\d{4}\/(\d{2}\/\d{2} \d{2}:\d{2})/);
                            return {
                                place: hypo.name || "震源地不明",
                                maxScale: Number(eq.maxScale ?? -1),
                                magnitude: Number(hypo.magnitude ?? -1),
                                depth: Number(hypo.depth ?? -1),
                                tsunami: eq.domesticTsunami || "Unknown",
                                rawTime: rawTime,
                                time: hmMatch ? hmMatch[1] : rawTime,
                                fullTime: fullMatch ? fullMatch[1] : rawTime
                            };
                        }).sort((a, b) => b.rawTime.localeCompare(a.rawTime));
                    }
                } catch (_) {}
            }
        }
        onExited: root.earthquakeLoading = false
    }
    Timer {
        interval: Math.max(15, settings.earthquakeInterval || 60) * 1000
        repeat: true
        running: settings.islandDisplay === "earthquake" && settings.earthquakeInterval > 0
        triggeredOnStart: true
        onTriggered: root.refreshEarthquake()
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
            earthquakeInfo: root.earthquakeInfo
            earthquakeHistory: root.earthquakeHistory
            earthquakeLoading: root.earthquakeLoading
            earthquakeLive: root.earthquakeLive && settings.earthquakeInterval === 0
            onEarthquakeRefreshRequested: root.refreshEarthquake()
            settingsController: settings
        }
    }
}
