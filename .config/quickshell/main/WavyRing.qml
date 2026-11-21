import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root
    property real percent: 0
    property string label: ""
    property string valueText: Math.round(percent) + "%"
    property color ringColor: LivePalette.color.primary
    property color trackColor: LivePalette.color.surfaceContainerHigh

    readonly property real clamped: Math.max(0, Math.min(100, percent))
    property real animatedPercent: clamped
    Behavior on animatedPercent {
        NumberAnimation { duration: Theme.motion.emphasized; easing.type: Easing.OutCubic }
    }

    implicitWidth: 68
    implicitHeight: 86

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56

            Canvas {
                id: ringCanvas
                anchors.fill: parent
                readonly property real pct: root.animatedPercent
                readonly property color fg: root.ringColor
                readonly property color bg: root.trackColor

                onPctChanged: requestPaint()
                onFgChanged: requestPaint()
                onBgChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width * 0.5;
                    const cy = height * 0.5;
                    const baseR = Math.min(width, height) * 0.5 - 6;

                    // Background track ring
                    ctx.beginPath();
                    ctx.arc(cx, cy, baseR, 0, Math.PI * 2);
                    ctx.strokeStyle = bg;
                    ctx.lineWidth = 4.5;
                    ctx.lineCap = "round";
                    ctx.stroke();

                    if (pct <= 0.5) return;

                    // M3 Expressive Wavy Arc
                    const start = -Math.PI * 0.5;
                    const span = (pct / 100.0) * Math.PI * 2;
                    const steps = Math.max(12, Math.round(span * 20));
                    const waves = 10;
                    const amp = 1.65;

                    ctx.beginPath();
                    for (let i = 0; i <= steps; ++i) {
                        const t = i / steps;
                        const angle = start + t * span;
                        const taper = Math.min(1.0, Math.min(i, steps - i) / 3.0);
                        const r = baseR + amp * taper * Math.sin(waves * angle);
                        const px = cx + r * Math.cos(angle);
                        const py = cy + r * Math.sin(angle);
                        if (i === 0) ctx.moveTo(px, py);
                        else ctx.lineTo(px, py);
                    }
                    ctx.strokeStyle = fg;
                    ctx.lineWidth = 4.2;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.stroke();
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.valueText
                font.family: Theme.font.display
                font.pixelSize: 13
                color: LivePalette.color.onSurface
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: LivePalette.color.onSurfaceVariant
        }
    }
}
