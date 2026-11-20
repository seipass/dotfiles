import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell

ColumnLayout {
    id: root
    property string selected
    signal chosen(string path)
    Label {
        text: "Pictures"
        color: LivePalette.color.onSurface
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
        cellHeight: 106
        model: FolderListModel {
            id: images
            folder: "file://" + Quickshell.env("HOME") + "/Pictures"
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
            showDirs: false
        }
        delegate: Button {
            id: tile
            required property url fileUrl
            required property string fileName
            width: grid.cellWidth - 6
            height: grid.cellHeight - 6
            Accessible.name: fileName
            onClicked: root.chosen(fileUrl.toString())
            contentItem: Image {
                source: tile.fileUrl
                sourceSize.width: 320
                sourceSize.height: 180
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                clip: true
            }
            background: Rectangle {
                color: root.selected === tile.fileUrl.toString() ? LivePalette.color.primary : LivePalette.color.surface
            }
        }
        ScrollBar.vertical: ScrollBar {}
    }
}
