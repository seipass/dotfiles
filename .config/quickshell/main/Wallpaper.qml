import Quickshell
import Quickshell.Wayland
import QtQuick
import "Theme.js" as Theme

PanelWindow {
    id: root
    property string imagePath: ""
    property bool showClock: false
    property date clockDate: new Date()
    property int front: 0
    property real turnAngle: 0
    readonly property var currentImage: front === 0 ? pageA.item : pageB.item
    readonly property var nextImage: front === 0 ? pageB.item : pageA.item
    visible: imagePath.length > 0 || showClock || turn.running
    color: LivePalette.color.surface
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Background
    mask: Region { width: 0; height: 0 }
    function preparePage() {
        if (!currentImage || !nextImage || turn.running
            || nextImage.source.toString() === imagePath && nextImage.status === Image.Loading) return;
        if (currentImage.source.toString() === imagePath) {
            nextImage.source = "";
            return;
        }
        nextImage.source = imagePath;
        checkPage();
    }

    function checkPage() {
        if (turn.running || nextImage.source.toString() !== imagePath
            || (imagePath && nextImage.status !== Image.Ready)) return;
        if (currentImage.status === Image.Ready && imagePath) turn.start();
        else finishPage();
    }

    function finishPage() {
        front = 1 - front;
        turnAngle = 0;
        nextImage.source = "";
        if (currentImage.source.toString() !== imagePath) preparePage();
    }

    onImagePathChanged: Qt.callLater(preparePage)
    Component.onCompleted: Qt.callLater(preparePage)

    NumberAnimation {
        id: turn
        target: root
        property: "turnAngle"
        from: 0
        to: -90
        duration: 420
        easing.type: Easing.InOutCubic
        onFinished: root.finishPage()
    }

    Component {
      id: wallpaperPage
      Image {
        id: page
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        clip: true
        visible: status === Image.Ready && (root.currentImage === page || turn.running)
        onStatusChanged: if (root.nextImage === page && status === Image.Ready) root.checkPage()
        transform: Rotation {
            origin.y: page.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.currentImage === page ? root.turnAngle : 0
        }
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.currentImage === page ? Math.abs(root.turnAngle) / 270 : 0
        }
      }
    }
    Loader { id: pageA; anchors.fill: parent; z: root.front === 0 ? 1 : 0; sourceComponent: wallpaperPage; onLoaded: Qt.callLater(root.preparePage) }
    Loader { id: pageB; anchors.fill: parent; z: root.front === 1 ? 1 : 0; sourceComponent: wallpaperPage; onLoaded: Qt.callLater(root.preparePage) }
    Rectangle {
        z: 2
        visible: root.showClock
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.13)
        width: 296
        height: 122
        radius: 28
        color: Qt.alpha(LivePalette.color.surfaceContainer, 0.88)
        Column {
            anchors.centerIn: parent
            spacing: 2
            RollingClock {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.clockDate, "HH:mm")
                fontFamily: Theme.font.display
                fontPixelSize: 52
                textColor: LivePalette.color.onSurface
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.clockDate, "dddd, MMMM d")
                font.pixelSize: 15
                font.weight: Font.Medium
                color: LivePalette.color.primary
            }
        }
    }
}
