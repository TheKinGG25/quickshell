// Left.qml - virtual desktop / workspace numbers on the left of the bar.
// Click a number to switch: root.switchDesktop() in shell.qml picks the right way for the
// running compositor (Hyprland dispatch, or scripts/kwin-desktop.py on Plasma).
// How many numbers: root.desktopCount in shell.qml.

import QtQuick

Row {
    id: leftRow
    property var root

    // ── Tweakables ──
    property color activeColor: "#ffffff"   // number of the current desktop (also bold)
    property color inactiveColor: "#666666" // other desktops
    property int clickHeight: 30            // height of the click area around each number
    spacing: 20                             // gap between numbers

    Repeater {
        model: root.desktopCount
        delegate: Text {
            id: text_element
            text: index + 1
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
