pragma Singleton
import QtQuick
import "Theme.js" as Theme

QtObject {
    property var color: Theme.color

    function apply(json): bool {
        try {
            const generated = JSON.parse(json);
            const next = {};
            for (const key of Object.keys(Theme.color)) {
                next[key] = typeof generated[key] === "string" && /^#[0-9a-fA-F]{6}$/.test(generated[key])
                    ? generated[key] : Theme.color[key];
            }
            if (JSON.stringify(next) !== JSON.stringify(color)) color = next;
            return true;
        } catch (error) {
            return false;
        }
    }
}
