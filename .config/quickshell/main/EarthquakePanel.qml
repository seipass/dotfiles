import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "Theme.js" as Theme

Item {
    id: root
    property var history: []
    property bool loading: false
    property bool liveMode: false
    property int selectedIndex: 0
    signal refreshRequested()
    signal closeRequested()

    onHistoryChanged: if (selectedIndex >= history.length) selectedIndex = 0
    readonly property var current: (history && history.length > selectedIndex) ? history[selectedIndex] : null

    function scaleText(scale) {
        switch (Number(scale)) {
        case 10: return "1";
        case 20: return "2";
        case 30: return "3";
        case 40: return "4";
        case 45: return "5弱";
        case 50: return "5強";
        case 55: return "6弱";
        case 60: return "6強";
        case 70: return "7";
        default: return "—";
        }
    }
    function scaleShort(scale) {
        switch (Number(scale)) {
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
    function scaleBg(scale) {
        const s = Number(scale);
        if (s >= 45) return LivePalette.color.errorContainer;
        if (s >= 30) return LivePalette.color.primaryContainer;
        return LivePalette.color.surfaceContainerHigh;
    }
    function scaleFg(scale) {
        const s = Number(scale);
        if (s >= 45) return LivePalette.color.error;
        if (s >= 30) return LivePalette.color.primary;
        return LivePalette.color.onSurface;
    }
    function tsunamiText(code) {
        switch (code) {
        case "None": return "津波の心配なし";
        case "Checking": return "津波調査中";
        case "NonEffective": return "若干の海面変動";
        case "Watch": return "津波注意報";
        case "Warning": return "津波警報";
        default: return "津波情報なし";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Earthquake"
                        font.family: Theme.font.display
                        font.pixelSize: 24
                        color: LivePalette.color.onSurface
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: root.liveMode
                        height: 22
                        radius: 11
                        color: LivePalette.color.primaryContainer
                        width: liveRow.implicitWidth + 14

                        Row {
                            id: liveRow
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: LivePalette.color.primary
                            }
                            Text {
                                text: "LIVE"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: LivePalette.color.primary
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.loading ? "最新の地震情報を取得中…"
                        : root.liveMode ? "リアルタイム監視中（P2P地震情報 WS）"
                        : "気象庁 地震情報（P2P地震情報）"
                    font.pixelSize: 12
                    color: LivePalette.color.onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            HeaderIconButton {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                iconName: "view-refresh-symbolic"
                label: "Refresh earthquake info"
                onClicked: root.refreshRequested()
            }
            HeaderIconButton {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                iconName: "window-close-symbolic"
                label: "Close"
                onClicked: root.closeRequested()
            }
        }

        // Hero Card (Selected / Latest Earthquake)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroCol.implicitHeight + 32
            radius: 24
            color: root.current && Number(root.current.maxScale) >= 45
                ? LivePalette.color.errorContainer
                : root.current && Number(root.current.maxScale) >= 30
                    ? LivePalette.color.primaryContainer
                    : LivePalette.color.surfaceContainer
            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

            ColumnLayout {
                id: heroCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Big M3 Intensity Badge
                    Rectangle {
                        Layout.preferredWidth: 62
                        Layout.preferredHeight: 62
                        radius: root.current && Number(root.current.maxScale) >= 30 ? 24 : 18
                        color: root.current && Number(root.current.maxScale) >= 45
                            ? LivePalette.color.error
                            : root.current && Number(root.current.maxScale) >= 30
                                ? LivePalette.color.primary
                                : LivePalette.color.surfaceContainerHigh
                        Behavior on radius { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "震度"
                                font.pixelSize: 10
                                color: root.current && Number(root.current.maxScale) >= 30
                                    ? LivePalette.color.onPrimary : LivePalette.color.onSurfaceVariant
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.current ? root.scaleText(root.current.maxScale) : "—"
                                font.family: Theme.font.display
                                font.pixelSize: 24
                                color: root.current && Number(root.current.maxScale) >= 30
                                    ? LivePalette.color.onPrimary : LivePalette.color.onSurface
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.current ? root.current.place : (root.loading ? "読み込み中…" : "地震情報はありません")
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            color: LivePalette.color.onSurface
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.current ? root.current.fullTime : "更新ボタンを押して取得"
                            font.pixelSize: 12
                            color: LivePalette.color.onSurfaceVariant
                        }
                    }
                }

                // Detail Chips Row (M3 Tonal Chips)
                Flow {
                    Layout.fillWidth: true
                    visible: !!root.current
                    spacing: 8

                    Rectangle {
                        height: 28
                        radius: 14
                        color: LivePalette.color.surfaceContainerHigh
                        width: magChip.implicitWidth + 22
                        Text {
                            id: magChip
                            anchors.centerIn: parent
                            text: root.current && root.current.magnitude > 0
                                ? "M" + Number(root.current.magnitude).toFixed(1) : "M —"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: LivePalette.color.primary
                        }
                    }

                    Rectangle {
                        height: 28
                        radius: 14
                        color: LivePalette.color.surfaceContainerHigh
                        width: depthChip.implicitWidth + 22
                        Text {
                            id: depthChip
                            anchors.centerIn: parent
                            text: root.current && root.current.depth >= 0
                                ? (root.current.depth === 0 ? "ごく浅い" : "深さ " + root.current.depth + "km") : "深さ不明"
                            font.pixelSize: 12
                            color: LivePalette.color.onSurface
                        }
                    }

                    Rectangle {
                        height: 28
                        radius: 14
                        color: root.current && (root.current.tsunami === "Warning" || root.current.tsunami === "Watch")
                            ? LivePalette.color.errorContainer : LivePalette.color.surfaceContainerHigh
                        width: tsunamiChip.implicitWidth + 22
                        Text {
                            id: tsunamiChip
                            anchors.centerIn: parent
                            text: root.current ? root.tsunamiText(root.current.tsunami) : ""
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root.current && (root.current.tsunami === "Warning" || root.current.tsunami === "Watch")
                                ? LivePalette.color.error : LivePalette.color.onSurface
                        }
                    }
                }
            }
        }

        // Section Label
        Text {
            Layout.fillWidth: true
            text: "RECENT EARTHQUAKES"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: LivePalette.color.onSurfaceVariant
        }

        // History List
        ListView {
            id: eqList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.history
            currentIndex: root.selectedIndex
            highlightFollowsCurrentItem: false
            ScrollBar.vertical: ScrollBar { active: true }

            highlight: Rectangle {
                readonly property Item cur: eqList.currentItem
                readonly property real targetTop: cur ? cur.y : 0
                readonly property real targetBot: cur ? (cur.y + cur.height) : 0
                property real headTop: targetTop
                property real tailTop: targetTop
                property real headBot: targetBot
                property real tailBot: targetBot

                Behavior on headTop { SpringAnimation { spring: Theme.motion.springLead; damping: Theme.motion.dampingLead } }
                Behavior on tailTop { SpringAnimation { spring: Theme.motion.springTrail; damping: Theme.motion.dampingTrail } }
                Behavior on headBot { SpringAnimation { spring: Theme.motion.springLead; damping: Theme.motion.dampingLead } }
                Behavior on tailBot { SpringAnimation { spring: Theme.motion.springTrail; damping: Theme.motion.dampingTrail } }

                width: eqList.width - 4
                y: Math.min(headTop, tailTop)
                height: Math.max(0, Math.max(headBot, tailBot) - y)
                radius: 18
                visible: !!cur && eqList.count > 0
                color: LivePalette.color.primaryContainer
                z: -1
            }

            delegate: Rectangle {
                id: eqRow
                required property var modelData
                required property int index
                readonly property bool isSelected: root.selectedIndex === index
                width: ListView.view.width - 4
                height: 54
                radius: isSelected ? 18 : 16
                color: isSelected ? "transparent" : LivePalette.color.surfaceContainer
                scale: rowMouse.pressed ? 0.96 : 1.0
                Behavior on radius { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }
                Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                Behavior on scale { NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootFast } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: LivePalette.color.onSurface
                    opacity: rowMouse.pressed ? 0.12 : rowMouse.containsMouse ? 0.07 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: root.scaleBg(eqRow.modelData.maxScale)

                        Text {
                            anchors.centerIn: parent
                            text: root.scaleShort(eqRow.modelData.maxScale)
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.scaleFg(eqRow.modelData.maxScale)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: eqRow.modelData.place
                            font.pixelSize: 13
                            font.weight: eqRow.isSelected ? Font.DemiBold : Font.Medium
                            color: LivePalette.color.onSurface
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: eqRow.modelData.fullTime
                            font.pixelSize: 11
                            color: LivePalette.color.onSurfaceVariant
                        }
                    }

                    Text {
                        text: eqRow.modelData.magnitude > 0 ? "M" + Number(eqRow.modelData.magnitude).toFixed(1) : "—"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: LivePalette.color.primary
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedIndex = eqRow.index
                }
            }
        }
    }
}
