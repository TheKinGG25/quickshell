// ValuePill.qml - colored bar pill with a value on the left and an icon on the right.
// Base of VolumePill and BatteryPill: they set valueText / icon / color and add their own MouseArea.
// Height, radius and font come from root (shell.qml).

import QtQuick

Rectangle {
    id: pill
    property var root
    property var screen

    property string valueText: ""           // left side, e.g. "42"
    property string icon: ""                // right side
    property color textColor: "black"       // both texts
    property int minWidth: 55
    property int padding: 4                 // space between the texts and the pill edge

    width: Math.max(valueLabel.implicitWidth + iconLabel.implicitWidth + 10, minWidth)
    height: root.pillHeight
    radius: root.pillRadius

    Text {
        id: valueLabel
        anchors.left: parent.left
        anchors.leftMargin: pill.padding
        anchors.verticalCenter: parent.verticalCenter
        text: pill.valueText
        color: pill.textColor
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Text {
        id: iconLabel
        anchors.right: parent.right
        anchors.rightMargin: pill.padding
        anchors.verticalCenter: parent.verticalCenter
        text: pill.icon
        color: pill.textColor
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }
}
