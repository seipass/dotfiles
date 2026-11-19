import QtQuick
import Quickshell.Hyprland
import "Theme.js" as Theme

Item {
    id: root
    property var player

    Column {
        anchors.left: parent.left
        anchors.right: playButton.left
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            width: parent.width
            text: root.player
                ? (root.player.isPlaying ? "" : "一時停止 · ") + (root.player.trackTitle || root.player.identity)
                : "再生中の音楽なし"
            color: LivePalette.color.onSurface
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Hyprland.activeToplevel && Hyprland.activeToplevel.title
                ? Hyprland.activeToplevel.title : "デスクトップ"
            color: LivePalette.color.onSurfaceVariant
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
    SymbolIcon {
        id: playButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18
        iconName: root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
        tint: LivePalette.color.primary
        opacity: root.player && root.player.canTogglePlaying ? 1 : 0.4
        MouseArea {
            anchors.fill: parent
            enabled: !!root.player && root.player.canTogglePlaying
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.togglePlaying()
        }
    }
}
