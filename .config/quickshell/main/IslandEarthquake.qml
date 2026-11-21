import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root
    property var earthquakeInfo: ({})
    property bool loading: false
    signal clicked()

    readonly property int maxScale: Number(earthquakeInfo?.maxScale ?? -1)
    readonly property string scaleLabel: {
        switch (maxScale) {
        case 10: return "1";
        case 20: return "2";
        case 30: return "3";
        case 40: return "4";
        case 45: return "5-";
        case 50: return "5+";
        case 55: return "6-";
        case 60: return "6+";
        case 70: return "7";
        default: return "—";
        }
    }
    readonly property color badgeBg: maxScale >= 45 ? LivePalette.color.errorContainer
        : maxScale >= 30 ? LivePalette.color.primaryContainer
        : LivePalette.color.surfaceContainerHigh
    readonly property color badgeFg: maxScale >= 45 ? LivePalette.color.error
        : maxScale >= 30 ? LivePalette.color.primary
        : LivePalette.color.onSurface

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: LivePalette.color.onSurface
        opacity: eqMouse.pressed ? 0.12 : eqMouse.containsMouse ? 0.07 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 4
        spacing: 7

        // M3 Intensity Pill Badge
        Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            radius: 13
            color: root.badgeBg
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

            Text {
                anchors.centerIn: parent
                text: root.scaleLabel
                color: root.badgeFg
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.earthquakeInfo?.place || (root.loading ? "地震情報を取得中…" : "地震情報なし")
                color: LivePalette.color.onSurface
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (!root.earthquakeInfo?.time) return "クリックで更新";
                    const mag = root.earthquakeInfo.magnitude > 0 ? " · M" + Number(root.earthquakeInfo.magnitude).toFixed(1) : "";
                    return root.earthquakeInfo.time + mag;
                }
                color: LivePalette.color.onSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: eqMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
