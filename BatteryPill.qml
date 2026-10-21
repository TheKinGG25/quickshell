// BatteryPill.qml - battery percent + charge arrow.
// Color steps down every 20%. Middle click: PowerProfileMenu. Data: root.battery* in shell.qml.

import QtQuick

Rectangle {
    id: batteryPill
    property var root
    property var screen

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
    property color textColor: "black"
    property int minWidth: 55

    property color pillColor: root.batteryLevel > 80 ? colorFull :
                              root.batteryLevel > 60 ? colorHigh :
                              root.batteryLevel > 40 ? colorMid :
                              root.batteryLevel > 20 ? colorLow : colorCritical

    property string icon: root.batteryStatus === "Charging"     ? chargingIcon :
                          root.batteryStatus === "Not charging" ? notChargingIcon : dischargingIcon

    width: Math.max(number.implicitWidth + icon_class.implicitWidth + 10, minWidth)
    height: root.pillHeight
    radius: root.pillRadius
    color: pillColor

    // Percent (left)
    Text {
        id:number
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.batteryLevel
        color: batteryPill.textColor
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    // Charge arrow (right)
    Text {
        id:icon_class
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: icon
        color: batteryPill.textColor
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.activePowerProfileScreen = (root.activePowerProfileScreen === screen ? null : screen)
        }
    }
}
