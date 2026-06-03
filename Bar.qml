import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Left { root: barWindow.root }

            Item { Layout.fillWidth: true }

            Center {}

            Item { Layout.fillWidth: true }

            Right { 
                root: barWindow.root 
                screen: barWindow.screen
            }
        }
    }
}
