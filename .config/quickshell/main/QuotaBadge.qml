import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Theme.js" as Theme

PanelWindow {
    id: root
    required property bool available
    required property var quota
    property string preferredProvider: "auto"
    signal refreshRequested()

    readonly property var providers: (quota && Array.isArray(quota.providers)) ? quota.providers : []
    readonly property var installedProviders: providers.filter(p => p.installed)
    property string manualProviderId: ""

    readonly property var activeProvider: {
        if (!providers.length) return null;
        if (manualProviderId) {
            const m = providers.find(p => p.id === manualProviderId);
            if (m) return m;
        }
        if (preferredProvider && preferredProvider !== "auto") {
            const pref = providers.find(p => p.id === preferredProvider);
            if (pref) return pref;
        }
        return providers.find(p => p.installed && p.windows && p.windows.length > 0)
            || providers.find(p => p.installed)
            || providers[0];
    }
    readonly property var windows: (activeProvider && activeProvider.windows) ? activeProvider.windows : []

    SystemClock { id: clock; precision: SystemClock.Minutes }
    property bool opened: false
    visible: available
    onAvailableChanged: if (!available) opened = false
    onPreferredProviderChanged: manualProviderId = ""
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    focusable: false
    mask: root.opened ? null : badgeInput
    Region { id: badgeInput; item: badge }
    FontLoader { id: uiFont; source: "fonts/GoogleSansFlex.ttf" }

    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.opened = false
    }

    // M3 Full Pill Badge
    Rectangle {
        id: badge
        anchors.right: parent.right
        anchors.rightMargin: 54
        y: 4
        width: badgeRow.implicitWidth + 20
        height: 32
        radius: 16
        color: root.opened ? LivePalette.color.primaryContainer : LivePalette.color.surface
        scale: badgeMouse.pressed ? 0.95 : 1.0
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: LivePalette.color.onSurface
            opacity: badgeMouse.pressed ? 0.12 : badgeMouse.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
        }

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 6

            ProviderIcon {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                providerId: root.activeProvider ? root.activeProvider.id : "auto"
                tint: root.opened ? LivePalette.color.primary : LivePalette.color.onSurface
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [300, 10080]
                    delegate: Rectangle {
                        id: track
                        required property int modelData
                        readonly property var window: root.windows.find(item => Number(item.minutes) === modelData)
                        readonly property bool known: !!window && !(window.reset > 0 && window.reset * 1000 <= clock.date.getTime())
                        width: 34
                        height: 4
                        radius: 2
                        color: known ? LivePalette.color.surfaceContainerHigh : "transparent"
                        border.width: known ? 0 : 1
                        border.color: LivePalette.color.outlineVariant
                        Rectangle {
                            width: track.known ? track.width * Math.max(0, Math.min(100, track.window.used)) / 100 : 0
                            height: track.height
                            radius: 2
                            color: track.window && track.window.alert ? LivePalette.color.error : LivePalette.color.primary
                            Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
        MouseArea {
            id: badgeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.name: "AI usage indicator"
            onClicked: root.opened = !root.opened
        }
    }

    // M3 Extra-Large Multi-Provider Popover Card
    Rectangle {
        id: card
        anchors.right: badge.right
        width: 312
        y: root.opened ? 44 : 38
        height: details.implicitHeight + 36
        radius: 24
        color: LivePalette.color.surfaceContainer
        opacity: root.opened ? 1 : 0
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        ColumnLayout {
            id: details
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ProviderIcon {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    providerId: root.activeProvider ? root.activeProvider.id : "auto"
                    tint: LivePalette.color.primary
                }

                Text {
                    text: root.activeProvider ? root.activeProvider.name : "AI Usage"
                    font.family: "Ndot 55"
                    font.pixelSize: 18
                    color: LivePalette.color.onSurface
                }

                Rectangle {
                    visible: !!root.activeProvider
                    height: 22
                    radius: 11
                    color: root.activeProvider && root.activeProvider.status === "Limit hit"
                        ? LivePalette.color.errorContainer
                        : root.activeProvider && (root.activeProvider.live || root.activeProvider.status === "Active")
                            ? LivePalette.color.primaryContainer
                            : LivePalette.color.surfaceContainerHigh
                    width: statusTxt.implicitWidth + 14

                    Text {
                        id: statusTxt
                        anchors.centerIn: parent
                        text: root.activeProvider ? root.activeProvider.status : ""
                        font.family: uiFont.name
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: root.activeProvider && root.activeProvider.status === "Limit hit"
                            ? LivePalette.color.error
                            : root.activeProvider && (root.activeProvider.live || root.activeProvider.status === "Active")
                                ? LivePalette.color.primary
                                : LivePalette.color.onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                HeaderIconButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 15
                    iconName: "view-refresh-symbolic"
                    label: "Refresh AI usage"
                    onClicked: root.refreshRequested()
                }
            }

            // Provider Switcher (M3 Filter Chips)
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.providers.length > 0

                Repeater {
                    model: root.providers
                    delegate: Rectangle {
                        id: provChip
                        required property var modelData
                        readonly property bool selected: root.activeProvider && root.activeProvider.id === modelData.id
                        height: 28
                        radius: 14
                        width: provChipRow.implicitWidth + 18
                        color: selected ? LivePalette.color.primaryContainer : "transparent"
                        border.width: selected ? 0 : 1
                        border.color: LivePalette.color.outlineVariant
                        opacity: modelData.installed || selected ? 1.0 : 0.48
                        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: LivePalette.color.onSurface
                            opacity: provMouse.pressed ? 0.12 : provMouse.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                        }

                        Row {
                            id: provChipRow
                            anchors.centerIn: parent
                            spacing: 5
                            ProviderIcon {
                                width: 12
                                height: 12
                                anchors.verticalCenter: parent.verticalCenter
                                providerId: provChip.modelData.id
                                tint: provChip.selected ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: provChip.modelData.name
                                font.family: uiFont.name
                                font.pixelSize: 11
                                font.weight: provChip.selected ? Font.DemiBold : Font.Medium
                                color: provChip.selected ? LivePalette.color.primary : LivePalette.color.onSurface
                            }
                        }

                        MouseArea {
                            id: provMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.manualProviderId = provChip.modelData.id
                        }
                    }
                }
            }

            Text {
                visible: !root.windows.length
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.activeProvider && !root.activeProvider.installed
                    ? root.activeProvider.name + " is not detected on this system."
                    : "No recent usage recorded yet."
                font.family: uiFont.name
                font.pixelSize: 12
                color: LivePalette.color.onSurfaceVariant
            }

            Repeater {
                model: root.windows
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: (modelData.label || "Window") + " window"
                            font.family: uiFont.name
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: LivePalette.color.onSurface
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modelData.detail || (Math.round(modelData.used) + "%")
                            font.family: uiFont.name
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: modelData.alert ? LivePalette.color.error : LivePalette.color.primary
                        }
                    }

                    // M3 Expressive Linear Progress Indicator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: LivePalette.color.surfaceContainerHigh
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, modelData.used)) / 100
                            height: parent.height
                            radius: 4
                            color: modelData.alert ? LivePalette.color.error : LivePalette.color.primary
                            Behavior on width { NumberAnimation { duration: Theme.motion.standard; easing.type: Easing.OutCubic } }
                        }
                    }

                    Text {
                        visible: (modelData.reset ?? 0) > 0
                        text: "Reset · " + Qt.formatDateTime(new Date(modelData.reset * 1000), "MMM d HH:mm")
                        font.family: uiFont.name
                        font.pixelSize: 11
                        color: LivePalette.color.onSurfaceVariant
                    }
                }
            }

            // Codex Reset Bank Card (shown when Codex is active)
            Rectangle {
                id: bankCard
                visible: !!(root.activeProvider && root.activeProvider.id === "codex" && root.activeProvider.resetBank)
                readonly property var bank: root.activeProvider ? root.activeProvider.resetBank : null
                readonly property int availCount: bank ? Number(bank.available ?? 0) : 0
                readonly property var creditList: bank && Array.isArray(bank.credits) ? bank.credits : []
                Layout.fillWidth: true
                radius: 16
                color: LivePalette.color.surfaceContainerHigh
                implicitHeight: bankCol.implicitHeight + 24

                ColumnLayout {
                    id: bankCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        SymbolIcon {
                            implicitWidth: 16
                            implicitHeight: 16
                            iconName: "view-refresh-symbolic"
                            tint: bankCard.availCount > 0 ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Reset Bank"
                            font.family: uiFont.name
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: LivePalette.color.onSurface
                        }

                        Rectangle {
                            height: 22
                            radius: 11
                            color: bankCard.availCount > 0
                                ? LivePalette.color.primaryContainer : LivePalette.color.surfaceContainer
                            width: bankCountTxt.implicitWidth + 14

                            Text {
                                id: bankCountTxt
                                anchors.centerIn: parent
                                text: bankCard.availCount + " available"
                                font.family: uiFont.name
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: bankCard.availCount > 0
                                    ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
                            }
                        }
                    }

                    Repeater {
                        model: bankCard.creditList
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            radius: 12
                            color: LivePalette.color.surfaceContainer
                            implicitHeight: 34

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: 10
                                    color: LivePalette.color.primaryContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: String(index + 1)
                                        font.family: uiFont.name
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: LivePalette.color.primary
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || "Full reset"
                                    font.family: uiFont.name
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: LivePalette.color.onSurface
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: (modelData.expiresAt ?? 0) > 0
                                    text: (modelData.expiresAt ?? 0) > 0
                                        ? "Exp " + Qt.formatDateTime(new Date(modelData.expiresAt * 1000), "MMM d")
                                        : ""
                                    font.family: uiFont.name
                                    font.pixelSize: 10
                                    color: LivePalette.color.onSurfaceVariant
                                }
                            }
                        }
                    }

                    Text {
                        visible: bankCard.creditList.length === 0
                        Layout.fillWidth: true
                        text: "No reset credits available"
                        font.family: uiFont.name
                        font.pixelSize: 11
                        color: LivePalette.color.onSurfaceVariant
                    }
                }
            }

            Text {
                visible: !!(root.activeProvider && root.activeProvider.timestamp)
                text: visible ? (root.activeProvider.live ? "Updated · " : "Last activity · ")
                    + Qt.formatDateTime(new Date(root.activeProvider.timestamp), "MMM d HH:mm") : ""
                font.family: uiFont.name
                font.pixelSize: 11
                color: LivePalette.color.onSurfaceVariant
            }
        }
    }
}
