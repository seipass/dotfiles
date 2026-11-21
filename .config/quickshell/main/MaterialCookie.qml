import QtQuick
import "Theme.js" as Theme

Canvas {
    id: root
    // morph: 0.0 = Cookie4 (clover), 1.0 = Cookie9 (scalloped), 2.0 = Circle
    property real morph: 0.0
    property color fillColor: LivePalette.color.primaryContainer
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real maxScallop: 0.13

    onMorphChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width;
        const h = height;
        if (w <= 2 || h <= 2) return;

        const cx = w * 0.5;
        const cy = h * 0.5;
        const baseR = Math.min(w, h) * 0.5 - strokeWidth - 1;
        const u = Math.max(0.0, Math.min(2.0, root.morph));
        const w4 = Math.max(0.0, 1.0 - u);
        const w9 = u <= 1.0 ? u : Math.max(0.0, 2.0 - u);
        const amp = u <= 1.0 ? root.maxScallop : root.maxScallop * (2.0 - u);

        const steps = 108;
        ctx.beginPath();
        for (let i = 0; i <= steps; ++i) {
            const theta = (i / steps) * Math.PI * 2;
            const wave = w4 * Math.cos(4 * theta) + w9 * Math.cos(9 * theta);
            const r = baseR * (1.0 - amp + amp * wave);
            const px = cx + r * Math.cos(theta);
            const py = cy + r * Math.sin(theta);
            if (i === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
        }
        ctx.closePath();

        ctx.fillStyle = root.fillColor;
        ctx.fill();
        if (root.strokeWidth > 0 && root.strokeColor !== "transparent") {
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = root.strokeColor;
            ctx.stroke();
        }
    }
}
