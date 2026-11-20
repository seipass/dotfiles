import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: action
    property bool primary: false
    property string iconName: ""
    font.pixelSize: 13
    font.weight: Font.Medium
    horizontalPadding: 16
    implicitHeight: 38

    contentItem: Row {
        spacing: 8
        anchors.centerIn: parent

        SymbolIcon {
            visible: action.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 16
            implicitHeight: 16
            iconName: action.iconName
            tint: action.primary ? LivePalette.color.onPrimary : action.hovered ? LivePalette.color.primary : LivePalette.color.onSurface
        }

        Text {
            text: action.text
            font: action.font
            anchors.verticalCenter: parent.verticalCenter
            color: action.primary ? LivePalette.color.onPrimary : action.hovered ? LivePalette.color.onSurface : LivePalette.color.onSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    background: Rectangle {
        radius: 10
        color: {
            if (!action.enabled) return Qt.alpha(LivePalette.color.surfaceContainerHigh, 0.4);
            if (action.primary) {
                return action.down ? Qt.darker(LivePalette.color.primary, 1.15) :
                       action.hovered ? Qt.lighter(LivePalette.color.primary, 1.08) : LivePalette.color.primary;
            }
            return action.down ? LivePalette.color.surfaceContainer :
                   action.hovered ? LivePalette.color.surfaceContainerHigh : Qt.alpha(LivePalette.color.surfaceContainerHigh, 0.6);
        }
        border.width: action.primary ? 0 : 1
        border.color: action.hovered ? Qt.alpha(LivePalette.color.primary, 0.4) : Qt.alpha(LivePalette.color.onSurface, 0.1)

        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }
    }
}
