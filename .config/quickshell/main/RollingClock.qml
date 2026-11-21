import QtQuick
import "Theme.js" as Theme

Row {
    id: root
    property string text: "00:00"
    property string fontFamily: Theme.font.display
    property int fontPixelSize: 20
    property color textColor: LivePalette.color.onSurface
    property int fontWeight: Font.Normal
    spacing: 0

    TextMetrics {
        id: digitMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        text: "0"
    }

    Repeater {
        model: root.text.length
        delegate: Item {
            id: slot
            required property int index
            readonly property string targetChar: root.text.charAt(index)
            readonly property bool isDigit: targetChar >= "0" && targetChar <= "9"
            property string activeChar: targetChar
            property string outgoingChar: ""
            property bool ready: false

            width: Math.ceil(isDigit ? Math.max(digitMetrics.advanceWidth, currTxt.implicitWidth) + 1 : Math.max(currTxt.implicitWidth, 4))
            height: Math.ceil(Math.max(digitMetrics.height, currTxt.implicitHeight) + 4)
            clip: true
            Behavior on width {
                NumberAnimation { duration: Theme.motion.spatialFast; easing.type: Easing.OutBack; easing.overshoot: Theme.motion.overshootGentle }
            }

            onTargetCharChanged: {
                if (!ready) {
                    activeChar = targetChar;
                    return;
                }
                if (targetChar === activeChar) return;
                outgoingChar = activeChar;
                activeChar = targetChar;
                rollAnim.restart();
            }

            Component.onCompleted: {
                activeChar = targetChar;
                ready = true;
            }

            ParallelAnimation {
                id: rollAnim
                NumberAnimation {
                    target: outTxt
                    property: "yOffset"
                    from: 0
                    to: -slot.height * 0.72
                    duration: Theme.motion.spatial
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: outTxt
                    property: "scale"
                    from: 1.0
                    to: 0.85
                    duration: Theme.motion.fast
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: outTxt
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Theme.motion.fast
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: currTxt
                    property: "yOffset"
                    from: slot.height * 0.72
                    to: 0
                    duration: Theme.motion.spatial
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.motion.overshootStandard
                }
                NumberAnimation {
                    target: currTxt
                    property: "scale"
                    from: 0.88
                    to: 1.0
                    duration: Theme.motion.spatial
                    easing.type: Easing.OutBack
                    easing.overshoot: Theme.motion.overshootStandard
                }
                NumberAnimation {
                    target: currTxt
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.motion.fast + 30
                    easing.type: Easing.OutCubic
                }
                onFinished: slot.outgoingChar = ""
            }

            Text {
                id: outTxt
                property real yOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + yOffset
                visible: slot.outgoingChar !== "" && opacity > 0
                text: slot.outgoingChar
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: root.fontWeight
                color: root.textColor
            }

            Text {
                id: currTxt
                property real yOffset: 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + yOffset
                text: slot.activeChar
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: root.fontWeight
                color: root.textColor
            }
        }
    }
}
