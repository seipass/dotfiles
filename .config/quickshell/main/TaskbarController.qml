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
        const grouped = {};
        const workspaces = Hyprland.workspaces.values;
        for (let i = 0; i < workspaces.length; ++i) {
            const windows = workspaces[i].toplevels.values;
            for (let j = 0; j < windows.length; ++j) {
                const win = windows[j];
                if (!win || !win.address) continue;
                const appId = win.handle ? win.handle.appId : (win.lastIpcObject.class || "");
                if (!appId) continue;
                const desktop = DesktopEntries.heuristicLookup(appId);
                const id = desktop ? desktop.id : appId;
                if (!grouped[id]) grouped[id] = { id: id, desktop: desktop, appId: appId, windows: [] };
                grouped[id].windows.push(win);
            }
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
    function activate(entry) {
        if (!entry) return;
        const win = entry.windows.find(w => w.activated) || entry.windows[0];
        if (win) {
            if (Hyprland.usingLua)
                Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + win.address + "' })");
            else Hyprland.dispatch("focuswindow address:" + win.address);
        } else if (entry.desktop) entry.desktop.execute();
    }
}
