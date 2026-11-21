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
    property real transitionProgress: 1.0
    readonly property var currentImage: front === 0 ? pageA.item : pageB.item
    readonly property var nextImage: front === 0 ? pageB.item : pageA.item
    visible: imagePath.length > 0 || showClock || fadeAnim.running
    color: LivePalette.color.surface
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Background
    mask: Region { width: 0; height: 0 }

    function preparePage() {
        if (!currentImage || !nextImage || fadeAnim.running
            || nextImage.source.toString() === imagePath && nextImage.status === Image.Loading) return;
        if (currentImage.source.toString() === imagePath) {
            nextImage.source = "";
            return;
        }
        nextImage.source = imagePath;
        checkPage();
    }

    function checkPage() {
        if (fadeAnim.running || nextImage.source.toString() !== imagePath
            || (imagePath && nextImage.status !== Image.Ready)) return;
        if (currentImage.status === Image.Ready && imagePath) {
            transitionProgress = 0.0;
            fadeAnim.start();
        } else {
            finishPage();
        }
    }

    function finishPage() {
        front = 1 - front;
        transitionProgress = 1.0;
        nextImage.source = "";
        if (currentImage.source.toString() !== imagePath) preparePage();
    }

    onImagePathChanged: Qt.callLater(preparePage)
    Component.onCompleted: Qt.callLater(preparePage)

    NumberAnimation {
        id: fadeAnim
        target: root
        property: "transitionProgress"
        from: 0.0
        to: 1.0
        duration: Theme.motion.spatialSlow + 40
        easing.type: Easing.OutCubic
        onFinished: root.finishPage()
    }

    Component {
      id: wallpaperPage
      Image {
        id: page
        readonly property bool isCurrent: root.currentImage === page
        readonly property bool isIncoming: root.nextImage === page
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        clip: true
        visible: status === Image.Ready && (isCurrent || (isIncoming && fadeAnim.running))
        opacity: isCurrent
            ? (fadeAnim.running ? 1.0 - root.transitionProgress * 0.35 : 1.0)
            : (isIncoming && fadeAnim.running ? root.transitionProgress : 0.0)
        scale: isIncoming && fadeAnim.running ? (1.035 - 0.035 * root.transitionProgress) : 1.0
        onStatusChanged: if (root.nextImage === page && status === Image.Ready) root.checkPage()
      }
    }
    Loader { id: pageA; anchors.fill: parent; z: root.front === 0 ? 0 : (fadeAnim.running ? 1 : 0); sourceComponent: wallpaperPage; onLoaded: Qt.callLater(root.preparePage) }
    Loader { id: pageB; anchors.fill: parent; z: root.front === 1 ? 0 : (fadeAnim.running ? 1 : 0); sourceComponent: wallpaperPage; onLoaded: Qt.callLater(root.preparePage) }

    Rectangle {
        z: 2
        opacity: root.showClock ? 1.0 : 0.0
        scale: root.showClock ? 1.0 : 0.92
        visible: opacity > 0.01
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.13)
        width: 296
        height: 122
        radius: 28
        color: Qt.alpha(LivePalette.color.surfaceContainer, 0.88)
        Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.spatial; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootStandard } }

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
