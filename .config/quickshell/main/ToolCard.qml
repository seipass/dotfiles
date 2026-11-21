import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: tCard
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string badge: ""
    property bool active: false
    property bool busy: false
    signal clicked()

    implicitHeight: subtitle ? 64 : 52
    radius: 20
    color: active ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
    opacity: enabled ? 1.0 : 0.5
    scale: tMouse.pressed ? 0.98 : 1.0

    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: LivePalette.color.onSurface
        opacity: tMouse.pressed ? 0.12 : tMouse.containsMouse ? 0.07 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        Rectangle {
            visible: tCard.iconName !== ""
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 19
            color: tCard.active ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh

            SymbolIcon {
                anchors.centerIn: parent
                implicitWidth: 18
                implicitHeight: 18
                iconName: tCard.iconName
                tint: tCard.active ? LivePalette.color.onPrimary : LivePalette.color.onSurface
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: tCard.title
                font.pixelSize: 13
                font.weight: Font.Medium
                color: LivePalette.color.onSurface
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: tCard.subtitle !== ""
                text: tCard.subtitle
                font.pixelSize: 11
                color: LivePalette.color.onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: tCard.badge !== ""
            radius: 12
            color: tCard.active ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh
            implicitWidth: badgeText.implicitWidth + 16
            implicitHeight: 24

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: tCard.badge
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: tCard.active ? LivePalette.color.onPrimary : LivePalette.color.onSurface
            }
        }
    }

    MouseArea {
        id: tMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: tCard.enabled && !tCard.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: tCard.clicked()
    }
}
