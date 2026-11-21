import QtQuick
import Quickshell.Hyprland
import "Theme.js" as Theme

Item {
    id: root
    property var player

    Column {
        anchors.left: parent.left
        anchors.right: playButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            width: parent.width
            text: root.player
                ? (root.player.isPlaying ? "" : "一時停止 · ") + (root.player.trackTitle || root.player.identity)
                : "再生中の音楽なし"
            color: LivePalette.color.onSurface
            font.pixelSize: 11
            font.weight: Font.Medium
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

    Rectangle {
        id: playButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24; radius: 12
        color: root.player && root.player.isPlaying ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainerHigh
        opacity: root.player && root.player.canTogglePlaying ? 1 : 0.4
        scale: playBtnMouse.pressed ? 0.92 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: LivePalette.color.onSurface
            opacity: playBtnMouse.pressed ? 0.14 : playBtnMouse.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
        }
        SymbolIcon {
            anchors.centerIn: parent
            width: 14; height: 14
            iconName: root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            tint: LivePalette.color.primary
        }
        MouseArea {
            id: playBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !!root.player && root.player.canTogglePlaying
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.togglePlaying()
        }
    }
}
