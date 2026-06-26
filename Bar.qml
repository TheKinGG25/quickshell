import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: barWindow
    property var root

    anchors { top: true; left: true; right: true }
    height: 30
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: "#30000000"

        Left {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            root: barWindow.root
        }

        Center {
            anchors.centerIn: parent
            height: parent.height
            root: barWindow.root
            screen: barWindow.screen
        }

        Right {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            root: barWindow.root
            screen: barWindow.screen
        }
    }
}
