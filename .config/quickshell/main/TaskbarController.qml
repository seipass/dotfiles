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
                const desktop = DesktopEntries.byId(id);
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
    function isPinned(id) { return pinnedIds.indexOf(id) >= 0; }
    function togglePin(id) {
        if (!id || !DesktopEntries.byId(id)) return;
        const pins = pinnedIds.slice();
        const index = pins.indexOf(id);
        if (index >= 0) pins.splice(index, 1);
        else pins.push(id);
        if (orderIds.indexOf(id) < 0) {
            const order = entries.map(entry => entry.id);
            if (order.indexOf(id) < 0) order.push(id);
            saved.order = JSON.stringify(order);
        }
        saved.pinned = JSON.stringify(pins);
    }
    function move(from, to) {
        const ids = entries.map(entry => entry.id);
        if (from < 0 || from >= ids.length || to < 0 || to >= ids.length || from === to) return;
        const item = ids.splice(from, 1)[0];
        ids.splice(to, 0, item);
        saved.order = JSON.stringify(ids);
    }
    function closeWindows(entry) {
        for (const win of entry.windows.slice()) {
            if (win.wayland) win.wayland.close();
            else {
                const address = win.address.startsWith("0x") ? win.address : "0x" + win.address;
                if (Hyprland.usingLua)
                    Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + address + "' })");
                else Hyprland.dispatch("closewindow address:" + address);
            }
        }
    }
    function activate(entry) {
        if (!entry) return;
        const win = entry.windows.find(w => w.activated) || entry.windows[0];
        if (win) {
            const address = win.address.startsWith("0x") ? win.address : "0x" + win.address;
            if (Hyprland.usingLua)
                Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + address + "' })");
            else Hyprland.dispatch("focuswindow address:" + address);
        } else if (entry.desktop) entry.desktop.execute();
    }
}
