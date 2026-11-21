import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: tgRow
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled()

    implicitHeight: subtitle ? 64 : 54
    radius: 20
    color: LivePalette.color.surfaceContainer
    opacity: enabled ? 1.0 : 0.5

    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: LivePalette.color.onSurface
        opacity: tgMouse.pressed ? 0.10 : tgMouse.containsMouse ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        Rectangle {
            visible: tgRow.iconName !== ""
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18
            color: tgRow.checked ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainerHigh
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

            SymbolIcon {
                anchors.centerIn: parent
                implicitWidth: 18
                implicitHeight: 18
                iconName: tgRow.iconName
                tint: tgRow.checked ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: tgRow.title
                font.pixelSize: 13
                font.weight: Font.Medium
                color: LivePalette.color.onSurface
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: tgRow.subtitle !== ""
                text: tgRow.subtitle
                font.pixelSize: 11
                color: LivePalette.color.onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        // Authentic Material 3 Switch (52x32)
        Rectangle {
            width: 52
            height: 32
            radius: 16
            color: tgRow.checked ? LivePalette.color.primary : LivePalette.color.surfaceContainerHigh
            border.width: tgRow.checked ? 0 : 2
            border.color: LivePalette.color.outlineVariant
            Behavior on color { ColorAnimation { duration: 180 } }

            Rectangle {
                readonly property real knobSize: tgMouse.pressed ? 26 : (tgRow.checked ? 24 : 16)
                x: tgRow.checked ? parent.width - width - 4 : (32 - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: knobSize
                height: knobSize
                radius: width / 2
                color: tgRow.checked ? LivePalette.color.onPrimary : LivePalette.color.onSurfaceVariant
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }

    MouseArea {
        id: tgMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: tgRow.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: tgRow.toggled()
    }
}
