import Quickshell
import QtQuick
import QtQuick.Effects
import "Theme.js" as Theme

Item {
    id: symbol
    property string iconName
    property color tint: LivePalette.color.onSurface
    implicitWidth: 18
    implicitHeight: 18
    Image {
        anchors.fill: parent
        source: Quickshell.iconPath(symbol.iconName)
        sourceSize.width: 32
        sourceSize.height: 32
        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: 1
            colorization: 1
            colorizationColor: symbol.tint
        }
    }
}
