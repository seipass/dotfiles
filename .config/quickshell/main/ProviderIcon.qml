import QtQuick
import QtQuick.Effects

Image {
    id: root
    property string providerId: "auto"
    property color tint: LivePalette.color.onSurface

    width: 16
    height: 16
    sourceSize: Qt.size(Math.max(32, width * 2), Math.max(32, height * 2))
    source: {
        switch (providerId) {
        case "codex": return Qt.resolvedUrl("codex-badge.svg");
        case "antigravity": return Qt.resolvedUrl("antigravity-badge.svg");
        case "opencode": return Qt.resolvedUrl("opencode-badge.svg");
        case "claude": return Qt.resolvedUrl("claude-badge.svg");
        case "mistral": return Qt.resolvedUrl("mistral-badge.svg");
        case "command-code": return Qt.resolvedUrl("command-code-badge.svg");
        case "gemini": return Qt.resolvedUrl("gemini-badge.svg");
        default: return Qt.resolvedUrl("ai-auto-badge.svg");
        }
    }
    smooth: true
    layer.enabled: true
    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: root.tint
    }
}
