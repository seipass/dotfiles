import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "Theme.js" as Theme

ColumnLayout {
    id: root
    spacing: 10
    property string selected
    signal chosen(string path)

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "PICTURES (" + images.count + ")"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            color: LivePalette.color.onSurfaceVariant
        }
        Item { Layout.fillWidth: true }
    }

    Label {
        visible: images.count === 0
        text: "No images in ~/Pictures"
        color: LivePalette.color.onSurfaceVariant
    }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: 112
        model: FolderListModel {
            id: images
            folder: "file://" + Quickshell.env("HOME") + "/Pictures"
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
            showDirs: false
        }
        delegate: Item {
            id: tile
            required property url fileUrl
            required property string fileName
            readonly property bool isSelected: root.selected === tile.fileUrl.toString()
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 14
                color: LivePalette.color.surfaceContainer
                border.width: tile.isSelected ? 2 : 1
                border.color: tile.isSelected ? LivePalette.color.primary
                            : wpMouse.containsMouse ? Qt.alpha(LivePalette.color.primary, 0.5) : Qt.alpha(LivePalette.color.onSurface, 0.08)
                clip: true
                scale: wpMouse.pressed ? 0.97 : 1.0
                Behavior on border.color { ColorAnimation { duration: Theme.motion.fast } }
                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    anchors.margins: tile.isSelected ? 2 : 1
                    source: tile.fileUrl
                    sourceSize.width: 320
                    sourceSize.height: 180
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 24
                    color: Qt.alpha(LivePalette.color.surface, 0.78)

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: tile.fileName
                        font.pixelSize: 11
                        color: tile.isSelected ? LivePalette.color.primary : LivePalette.color.onSurface
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: wpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.name: tile.fileName
                    onClicked: root.chosen(tile.fileUrl.toString())
                }
            }
        }
        ScrollBar.vertical: ScrollBar {}
    }
}
