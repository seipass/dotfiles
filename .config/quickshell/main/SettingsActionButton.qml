import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: action
    property bool primary: false
    property string iconName: ""
    font.family: "Google Sans Flex"
    font.pixelSize: 13
    font.weight: Font.Medium
    horizontalPadding: 20
    implicitHeight: 40

    contentItem: Row {
        spacing: 8
        anchors.centerIn: parent

        SymbolIcon {
            visible: action.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 18
            implicitHeight: 18
            iconName: action.iconName
            tint: action.primary ? LivePalette.color.onPrimary : LivePalette.color.onSurface
        }

        Text {
            text: action.text
            font: action.font
            anchors.verticalCenter: parent.verticalCenter
            color: action.primary ? LivePalette.color.onPrimary : LivePalette.color.onSurface
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    background: Rectangle {
        radius: height / 2
        color: !action.enabled
            ? Qt.alpha(LivePalette.color.onSurface, 0.12)
            : action.primary
                ? LivePalette.color.primary
                : LivePalette.color.surfaceContainerHigh
        scale: action.down ? 0.97 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        // M3 State Layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: action.primary ? LivePalette.color.onPrimary : LivePalette.color.onSurface
            opacity: !action.enabled ? 0 : action.down ? 0.12 : action.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
        }
    }
}
