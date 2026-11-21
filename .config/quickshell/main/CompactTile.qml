import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: cTile
    property string iconName: ""
    property string title: ""
    signal clicked()

    implicitHeight: 48
    radius: 20
    color: LivePalette.color.surfaceContainer
    scale: cMouse.pressed ? 0.97 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: LivePalette.color.onSurface
        opacity: cMouse.pressed ? 0.12 : cMouse.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 10

        SymbolIcon {
            implicitWidth: 17
            implicitHeight: 17
            iconName: cTile.iconName
            tint: cMouse.containsMouse ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            text: cTile.title
            font.pixelSize: 13
            font.weight: Font.Medium
            color: LivePalette.color.onSurface
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: cMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cTile.clicked()
    }
}
