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
    radius: tMouse.pressed ? 14 : (active ? height / 2 : 18)
    color: active ? LivePalette.color.primary : LivePalette.color.surfaceContainer
    opacity: enabled ? 1.0 : 0.5
    scale: tMouse.pressed ? 0.96 : 1.0

    Behavior on radius {
        NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard }
    }
    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    Behavior on scale {
        NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: tCard.active ? LivePalette.color.onPrimary : LivePalette.color.onSurface
        opacity: tMouse.pressed ? 0.14 : tMouse.containsMouse ? 0.08 : 0
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
            radius: tCard.active ? 19 : 13
            color: tCard.active
                ? Qt.alpha(LivePalette.color.onPrimary, 0.16)
                : LivePalette.color.surfaceContainerHigh
            Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

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
                font.weight: tCard.active ? Font.DemiBold : Font.Medium
                color: tCard.active ? LivePalette.color.onPrimary : LivePalette.color.onSurface
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: tCard.subtitle !== ""
                text: tCard.subtitle
                font.pixelSize: 11
                color: tCard.active
                    ? Qt.alpha(LivePalette.color.onPrimary, 0.80)
                    : LivePalette.color.onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: tCard.badge !== ""
            radius: tCard.active ? 12 : 8
            color: tCard.active
                ? Qt.alpha(LivePalette.color.onPrimary, 0.16)
                : LivePalette.color.surfaceContainerHigh
            implicitWidth: badgeText.implicitWidth + 16
            implicitHeight: 24
            Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

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
