// Left.qml - virtual desktop / workspace numbers on the left of the bar, one per screen.
// Click a number to switch: root.switchDesktop() in shell.qml picks the right way for the
// running compositor (Hyprland grid.lua, or scripts/kwin-desktop.py on Plasma).
// How many numbers: root.desktopCount in shell.qml. On Hyprland each one reads [n,m], with m
// taken from this screen's own grid state (root.gridM).

import QtQuick

Row {
    id: leftRow
    property var root
    property var screen

    // ── Tweakables ──
    property color activeColor: "#ffffff"   // number of the current desktop (also bold)
    property color inactiveColor: "#666666" // other desktops
    property int clickHeight: 30            // height of the click area around each number
    spacing: 20                             // gap between numbers

    Repeater {
        model: root.desktopCount
        delegate: Text {
            id: text_element
            text: root.hyprland && leftRow.screen
                  ? "[" + (index + 1) + "," + root.gridM(leftRow.screen.name, index + 1) + "]"
                  : index + 1
            color: (index + 1) === root.currentDesktop ? leftRow.activeColor : leftRow.inactiveColor
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: (index + 1) === root.currentDesktop

            MouseArea {
                // Expand click area by half the spacing on each side
                anchors.centerIn: parent
                width: parent.width + leftRow.spacing
                height: leftRow.clickHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: root.switchDesktop(index + 1)
            }
        }
    }
}
