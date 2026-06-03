import QtQuick
import Quickshell.Io
import QtQuick.Layouts

RowLayout {
    property var root
    spacing: 0

    Repeater {
        model: 4
        delegate: Item {
            Layout.preferredWidth: text_element.implicitWidth + 24
            Layout.fillHeight: true

            Text {
                id: text_element
                anchors.centerIn: parent
                text: index + 1
                color: (index + 1) === root.currentDesktop ? "#ffffff" : "#666666"
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                font.bold: (index + 1) === root.currentDesktop
            }

            MouseArea {
                anchors.fill: parent
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
