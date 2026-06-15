import QtQuick
import Quickshell.Io

Row {
    property var root
    spacing: 20

    Repeater {
        model: 6
        delegate: Text {
            id: text_element
            text: index + 1
            color: (index + 1) === root.currentDesktop ? "#ffffff" : "#666666"
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: (index + 1) === root.currentDesktop

            MouseArea {
                // Expand click area by half the spacing on each side
                anchors.centerIn: parent
                width: parent.width + 20
                height: 30
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentDesktop = index + 1
                    switchProcess.command = ["python3", "/home/thekingg/.config/quickshell/scripts/kwin-desktop.py", (index + 1).toString()]
                    switchProcess.running = false
                    switchProcess.running = true
                }
            }
        }
    }

    Process {
        id: switchProcess
    }
}
