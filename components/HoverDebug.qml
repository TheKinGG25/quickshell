// HoverDebug.qml - translucent overlay marking the area the mouse can stay in without the
// popup closing. Only drawn while root.debugPopups is true (shell.qml -> "Debug").
// Put one in each popup, sized to the area that actually keeps the popup open:
//   HoverDebug { anchors.fill: parent; root: <windowId>.root; label: "volume" }
// It never takes the mouse, so it cannot change the behaviour it is showing.

import QtQuick

Rectangle {
    id: debugBox
    property var root
    property string label: ""
    property color markColor: "#00e676"     // green: inside = the popup stays open

    visible: root && root.debugPopups
    enabled: false                          // no input, ever
    z: 9999
    color: Qt.rgba(markColor.r, markColor.g, markColor.b, 0.10)
    border.color: Qt.rgba(markColor.r, markColor.g, markColor.b, 0.9)
    border.width: 1

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 2
        text: debugBox.label + " " + Math.round(debugBox.width) + "x" + Math.round(debugBox.height)
        color: debugBox.markColor
        font.pixelSize: 10
        font.family: debugBox.root ? debugBox.root.fontFamily : "monospace"
    }
}
