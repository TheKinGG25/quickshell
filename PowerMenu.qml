import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: powerWindow
    property var root
anchors { top: true; left: true; right: true }

margins.top: 0 // Start from screen top to cover the bar area with buffer

// Window width includes side buffers
property int windowWidth: contentRow.implicitWidth + 140
margins.left: (screen.width - windowWidth) / 2
margins.right: (screen.width - windowWidth) / 2

implicitWidth: windowWidth
implicitHeight: contentRow.implicitHeight + 130

color: "transparent"
visible: root && root.activePowerScreen === screen

WlrLayershell.layer: WlrLayer.Overlay
WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
WlrLayershell.namespace: "quickshell-powermenu"
WlrLayershell.exclusiveZone: -1

MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onExited: root.activePowerScreen = null

    // Debug area: semi-transparent blue to see the hit zone
    Rectangle {
        anchors.fill: parent
        color: "blue"
        opacity: 0.1
        border.color: "blue"
        border.width: 1
    }

    Rectangle {
        width: contentRow.implicitWidth + 40
        height: contentRow.implicitHeight + 40
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30 // Position the visible menu right below the bar

        radius: 16
        color: "#DD11111b"
        border.color: "#313244"
        border.width: 1

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 28

                PowerButton {
                    btnIcon: ""
                    label: "Shutdown"
                    btnColor: "#f38ba8"
                    onClicked: poweroffProc.running = true
                }

                PowerButton {
                    btnIcon: ""
                    label: "Restart"
                    btnColor: "#fab387"
                    onClicked: rebootProc.running = true
                }

                PowerButton {
                    btnIcon: "󰒲"
                    label: "Sleep"
                    btnColor: "#f9e2af"
                    onClicked: suspendProc.running = true
                }

                PowerButton {
                    btnIcon: "󰌾"
                    label: "Lock"
                    btnColor: "#89b4fa"
                    onClicked: lockProc.running = true
                }
            }
        }
    }

    Process { id: poweroffProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process { id: lockProc; command: ["loginctl", "lock-session"] }

    component PowerButton: Button {
        id: control
        property string btnIcon: ""
        property string label: ""
        property color btnColor: "white"

        contentItem: ColumnLayout {
            spacing: 8
            Text {
                text: control.btnIcon
                font.family: root ? root.fontFamily : "sans-serif"
                font.pixelSize: 32
                color: control.btnColor
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: control.label
                font.family: root ? root.fontFamily : "sans-serif"
                font.pixelSize: 12
                color: "#cdd6f4"
                Layout.alignment: Qt.AlignHCenter
            }
        }

        background: Rectangle {
            implicitWidth: 90
            implicitHeight: 90
            radius: 12
            color: control.hovered ? "#313244" : "transparent"
            border.color: control.hovered ? control.btnColor : "transparent"
            border.width: 1
        }
    }
}
