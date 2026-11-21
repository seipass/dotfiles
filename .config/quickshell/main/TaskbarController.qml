import Quickshell
import Quickshell.Hyprland
import QtCore

Scope {
    id: root
    Settings {
        id: saved
        location: "file://" + Quickshell.env("HOME") + "/.config/quickshell/main/taskbar.ini"
        category: "Taskbar"
        property string pinned: "[]"
        property string order: "[]"
    }
    function parse(value) {
        try { const result = JSON.parse(value); return Array.isArray(result) ? result : []; }
        catch (e) { return []; }
    }
    readonly property var pinnedIds: parse(saved.pinned)
    readonly property var orderIds: parse(saved.order)

    readonly property var entries: {
        const grouped = Object.create(null);
        for (const win of Hyprland.toplevels.values) {
            if (!win || !win.address) continue;
            const ipc = win.lastIpcObject;
            const candidates = [win.wayland?.appId, ipc?.class, ipc?.initialClass].filter(Boolean);
            if (!candidates.length) continue;
            const appId = candidates[0];
            let desktop = null;
            for (const candidate of candidates) {
                desktop = DesktopEntries.heuristicLookup(candidate)
                    || DesktopEntries.heuristicLookup(candidate.toLowerCase());
                if (desktop) break;
            }
            const id = desktop ? desktop.id : appId.toLowerCase();
            if (!grouped[id]) grouped[id] = { id: id, desktop: desktop, appId: appId, windows: [] };
            grouped[id].windows.push(win);
        }
        for (const id of pinnedIds) {
            if (!grouped[id]) {
                const desktop = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
                if (desktop) grouped[id] = { id: id, desktop: desktop, appId: id, windows: [] };
            }
        }
        const ids = Object.keys(grouped);
        ids.sort((a, b) => {
            const ai = orderIds.indexOf(a), bi = orderIds.indexOf(b);
            if (ai < 0 && bi < 0) return a.localeCompare(b);
            if (ai < 0) return 1;
            if (bi < 0) return -1;
            return ai - bi;
        });
        return ids.map(id => grouped[id]);
    }

    function entriesForMonitor(monitor, currentMonitorOnly) {
        if (!currentMonitorOnly || !monitor || !monitor.name) return entries;
        const monName = monitor.name;
        const result = [];
        for (const entry of entries) {
            const wins = entry.windows.filter(w => w.monitor?.name === monName);
            if (wins.length > 0 || isPinned(entry.id)) {
                result.push({ id: entry.id, desktop: entry.desktop, appId: entry.appId, windows: wins });
            }
        }
        return result;
    }

    function findEntry(id, monitor, currentMonitorOnly) {
        if (!id) return null;
        const base = entries.find(e => e.id === id) || null;
        if (!base) return null;
        if (!currentMonitorOnly || !monitor || !monitor.name) return base;
        const monName = monitor.name;
        const wins = base.windows.filter(w => w.monitor?.name === monName);
        if (wins.length === 0 && !isPinned(id)) return null;
        return { id: base.id, desktop: base.desktop, appId: base.appId, windows: wins };
    }

    function isPinned(id) { return pinnedIds.indexOf(id) >= 0; }

    function pruneOrder(ids, pins) {
        const activeIds = new Set();
        for (const entry of entries) activeIds.add(entry.id);
        for (const pid of pins) activeIds.add(pid);
        return ids.filter(id => activeIds.has(id));
    }

    function togglePin(id) {
        if (!id || !(DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id))) return;
        const pins = pinnedIds.slice();
        const index = pins.indexOf(id);
        if (index >= 0) pins.splice(index, 1);
        else pins.push(id);

        let order = orderIds.length ? orderIds.slice() : entries.map(e => e.id);
        for (const entry of entries) {
            if (order.indexOf(entry.id) < 0) order.push(entry.id);
        }
        if (order.indexOf(id) < 0) order.push(id);
        saved.order = JSON.stringify(pruneOrder(order, pins));
        saved.pinned = JSON.stringify(pins);
    }

    function move(from, to, visibleIds) {
        const list = Array.isArray(visibleIds) && visibleIds.length ? visibleIds : entries.map(e => e.id);
        if (from < 0 || from >= list.length || to < 0 || to >= list.length || from === to) return;
        const fromId = list[from];
        const toId = list[to];
        if (!fromId || !toId || fromId === toId) return;

        let full = entries.map(e => e.id);
        const fi = full.indexOf(fromId);
        const ti = full.indexOf(toId);
        if (fi < 0 || ti < 0 || fi === ti) return;
        const item = full.splice(fi, 1)[0];
        full.splice(ti, 0, item);
        saved.order = JSON.stringify(pruneOrder(full, pinnedIds));
    }

    function launchNew(entry) {
        if (entry && entry.desktop) entry.desktop.execute();
    }

    function focusWindow(win) {
        if (!win || !win.address) return;
        const address = win.address.startsWith("0x") ? win.address : "0x" + win.address;
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + address + "' })");
        else Hyprland.dispatch("focuswindow address:" + address);
    }

    function closeWindow(win) {
        if (!win) return;
        if (win.wayland) win.wayland.close();
        else if (win.address) {
            const address = win.address.startsWith("0x") ? win.address : "0x" + win.address;
            if (Hyprland.usingLua)
                Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + address + "' })");
            else Hyprland.dispatch("closewindow address:" + address);
        }
    }

    function closeWindows(entry, monitor, currentMonitorOnly) {
        if (!entry) return;
        let wins = entry.windows || [];
        if (currentMonitorOnly && monitor && monitor.name) {
            wins = wins.filter(w => w.monitor?.name === monitor.name);
        }
        for (const win of wins.slice()) closeWindow(win);
    }

    function activate(entry, targetMonitor) {
        if (!entry) return;
        const wins = entry.windows || [];
        if (wins.length === 0) {
            launchNew(entry);
            return;
        }
        const activeIdx = wins.findIndex(w => w.activated);
        if (activeIdx >= 0) {
            // Cycle to the next window when clicking an already active multi-window app
            focusWindow(wins[(activeIdx + 1) % wins.length]);
            return;
        }
        const onMonitor = targetMonitor && targetMonitor.name
            ? wins.find(w => w.monitor?.name === targetMonitor.name)
            : null;
        focusWindow(onMonitor || wins[0]);
    }
}
