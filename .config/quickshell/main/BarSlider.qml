import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Slider {
    id: control
    property bool wavy: false
    property bool waveAnimated: false
    property real waveAmplitude: 3.0
    property real waveLength: 24.0
    property real wavePhase: 0.0

    implicitHeight: 28
    leftPadding: 2
    rightPadding: 2

    NumberAnimation on wavePhase {
        running: control.wavy && control.waveAnimated && control.visible
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 950
    }

    onVisualPositionChanged: if (control.wavy) waveCanvas.requestPaint()
    onWavePhaseChanged: if (control.wavy) waveCanvas.requestPaint()
    onEnabledChanged: if (control.wavy) waveCanvas.requestPaint()

    background: Item {
        id: trackBox
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 16

        readonly property real handleW: control.pressed ? 6 : 4
        readonly property real handleCenter: control.visualPosition * Math.max(0, width - handleW) + handleW * 0.5
        readonly property real gap: 5
        readonly property real activeEnd: Math.max(0, handleCenter - handleW * 0.5 - gap)
        readonly property real inactiveStart: Math.min(width, handleCenter + handleW * 0.5 + gap)

        // Inactive Track (subtle right pill after handle gap)
        Rectangle {
            x: trackBox.inactiveStart
            width: Math.max(0, trackBox.width - x)
            height: 6
            anchors.verticalCenter: parent.verticalCenter
            radius: 3
            visible: width > 2
            color: LivePalette.color.surfaceContainerHigh
        }

        // Standard Expressive Solid Active Track
        Rectangle {
            visible: !control.wavy && width > 2
            x: 0
            width: trackBox.activeEnd
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            radius: 6
            color: control.enabled ? LivePalette.color.primary : LivePalette.color.outlineVariant
            Behavior on width {
                enabled: !control.pressed
                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }
        }

        // M3 Expressive Wavy Active Track
        Canvas {
            id: waveCanvas
            visible: control.wavy
            anchors.fill: parent
            readonly property color fg: control.enabled ? LivePalette.color.primary : LivePalette.color.outlineVariant
            readonly property real endX: trackBox.activeEnd

            onFgChanged: requestPaint()
            onEndXChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const limitX = endX - 2;
                if (limitX <= 3) return;

                const cy = height * 0.5;
                const amp = control.waveAnimated ? control.waveAmplitude : 1.6;
                const k = (Math.PI * 2) / Math.max(10, control.waveLength);

                ctx.beginPath();
                const startX = 2;
                for (let px = startX; px <= limitX; px += 2) {
                    const edgeDist = Math.min(px - startX, limitX - px);
                    const taper = Math.min(1.0, edgeDist / 6.0);
                    const py = cy + amp * taper * Math.sin(px * k - control.wavePhase);
                    if (px === startX) ctx.moveTo(px, py);
                    else ctx.lineTo(px, py);
                }
                ctx.lineTo(limitX, cy);
                ctx.strokeStyle = fg;
                ctx.lineWidth = 4.2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.stroke();
            }
        }
    }

    // M3 Expressive Vertical Pill Handle
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.pressed ? 6 : 4
        height: control.pressed ? 26 : 24
        radius: width / 2
        color: control.enabled ? LivePalette.color.primary : LivePalette.color.onSurfaceVariant
        Behavior on width { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
    }
}
