import QtQuick
import Quickshell
import Quickshell.Io
import "Theme.js" as Theme

Item {
    id: root
    property var paletteColors: LivePalette.color

    width: 165
    height: 24

    property int officialPercent: -1
    property int rawPercent: -1
    property int voltageRaw: -1
    property string processOutput: ""
    property string processError: ""
    property string errorMessage: ""

    function refreshBattery() {
        if (batteryProcess.running)
            return;
        errorMessage = "";
        processError = "";
        batteryProcess.running = true;
    }

    function applyReport(jsonText) {
        try {
            const report = JSON.parse(jsonText);
            const official = Number(report.voltage_based_estimate_percent);
            const raw = Number(report.battery_raw_percent);
            const voltage = Number(report.battery_voltage_raw);
            if (!isFinite(official) || !isFinite(raw) || !isFinite(voltage))
                throw new Error("battery fields are missing");

            officialPercent = official;
            rawPercent = raw;
            voltageRaw = voltage;
            errorMessage = "";
        } catch (error) {
            errorMessage = "Invalid battery response: " + error;
            console.warn(errorMessage);
        }
    }

    Process {
        id: batteryProcess
        command: ["python3", Quickshell.env("HOME") + "/vm600pe-battery.py", "--json"]

        stdout: StdioCollector {
            onStreamFinished: root.processOutput = this.text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: root.processError = this.text.trim()
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.applyReport(root.processOutput);
            else {
                root.errorMessage = root.processError || "Battery query exited with code " + exitCode;
                console.warn(root.errorMessage);
            }
            root.processOutput = "";
            root.processError = "";
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.refreshBattery()
    }

    Component.onCompleted: refreshBattery()

    Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.family: "Ndot 55"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: root.errorMessage ? root.paletteColors.error : root.paletteColors.onSurface
        text: root.errorMessage
            ? "Battery read error"
            : root.officialPercent < 0 || root.rawPercent < 0
                ? "Official --% / Raw --%"
                : "Official " + root.officialPercent + "% / Raw " + root.rawPercent + "%"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refreshBattery()
        }
    }
}
