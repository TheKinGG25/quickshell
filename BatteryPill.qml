// BatteryPill.qml - battery percent + charge arrow (layout: components/ValuePill.qml).
// Color steps down every 20%. Middle click: PowerProfileMenu. Data: root.battery* in shell.qml.

import QtQuick
import "components"

ValuePill {
    id: batteryPill

    // ── Tweakables ──
    // Color thresholds: above 80, 60, 40, 20, and below 20
    property color colorFull: "#2ecc71"
    property color colorHigh: "#a8d832"
    property color colorMid: "#f1c40f"
    property color colorLow: "#e67e22"
    property color colorCritical: "#e74c3c"
    property string chargingIcon: "↑"
    property string notChargingIcon: "-"        // plugged in but not charging (e.g. charge limit reached)
    property string dischargingIcon: "↓"
    textColor: "black"
    minWidth: 55

    color: root.batteryLevel > 80 ? colorFull :
           root.batteryLevel > 60 ? colorHigh :
           root.batteryLevel > 40 ? colorMid :
           root.batteryLevel > 20 ? colorLow : colorCritical
    icon: root.batteryStatus === "Charging"     ? chargingIcon :
          root.batteryStatus === "Not charging" ? notChargingIcon : dischargingIcon
    valueText: root.batteryLevel

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.activePowerProfileScreen = (root.activePowerProfileScreen === screen ? null : screen)
        }
    }
}
