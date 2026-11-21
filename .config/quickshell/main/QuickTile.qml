import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: qTile
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasChevron: true
    signal clicked()

    implicitHeight: 70
    radius: active ? height / 2 : 22
    color: active ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
    scale: qMouse.pressed ? 0.97 : 1.0

    Behavior on radius { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    // M3 State Layer
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: LivePalette.color.onSurface
        opacity: qMouse.pressed ? 0.12 : qMouse.containsMouse ? 0.07 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 11

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: qTile.active ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

            SymbolIcon {
                anchors.centerIn: parent
                implicitWidth: 18
                implicitHeight: 18
                iconName: qTile.iconName
                tint: qTile.active ? LivePalette.color.onPrimary : LivePalette.color.onSurface
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: qTile.title
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: LivePalette.color.onSurface
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: qTile.subtitle
                font.pixelSize: 11
                color: qTile.active ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Text {
            visible: qTile.hasChevron
            text: "›"
            font.pixelSize: 16
            color: Qt.alpha(LivePalette.color.onSurfaceVariant, qMouse.containsMouse ? 0.9 : 0.45)
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        }
    }

    MouseArea {
        id: qMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: qTile.clicked()
    }
}
