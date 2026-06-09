import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: profileWindow
    property var root

    anchors { top: true; right: true }
    margins.top: 0
    margins.right: 0
    width: 240
    height: contentCol.implicitHeight + 80
    color: "transparent"
    visible: root && root.activePowerProfileScreen === screen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-powerprofile"
    WlrLayershell.exclusiveZone: 0

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: root.activePowerProfileScreen = null

        Rectangle {
            width: 220
            height: contentCol.implicitHeight + 24
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.rightMargin: 0

            radius: 12
            color: "#DD11111b"
            border.color: "#313244"
            border.width: 1

            ColumnLayout {
                id: contentCol
                anchors.centerIn: parent
                spacing: 4

                ProfileButton {
                    btnIcon: "󱐌"
                    label: "Performance"
                    btnColor: "#f38ba8"
                    isActive: root && root.powerProfile === "performance"
                    onClicked: {
                        setPerformanceProc.running = false
                        setPerformanceProc.running = true
                        root.powerProfile = "performance"
                    }
                }

                ProfileButton {
                    btnIcon: "󱐋"
                    label: "Balanced"
                    btnColor: "#a6e3a1"
                    isActive: root && root.powerProfile === "balanced"
                    onClicked: {
                        setBalancedProc.running = false
                        setBalancedProc.running = true
                        root.powerProfile = "balanced"
                    }
                }

                ProfileButton {
                    btnIcon: "󰾆"
                    label: "Power Saver"
                    btnColor: "#89b4fa"
                    isActive: root && root.powerProfile === "power-saver"
                    onClicked: {
                        setPowerSaverProc.running = false
                        setPowerSaverProc.running = true
                        root.powerProfile = "power-saver"
                    }
                }
            }
        }
    }

    Process { id: setPerformanceProc; command: ["powerprofilesctl", "set", "performance"] }
    Process { id: setBalancedProc; command: ["powerprofilesctl", "set", "balanced"] }
    Process { id: setPowerSaverProc; command: ["powerprofilesctl", "set", "power-saver"] }

    component ProfileButton: Button {
        id: pbControl
        property string btnIcon: ""
        property string label: ""
        property color btnColor: "white"
        property bool isActive: false

        Layout.fillWidth: true

        contentItem: RowLayout {
            spacing: 10

            Text {
                text: pbControl.btnIcon
                font.family: root ? root.fontFamily : "sans-serif"
                font.pixelSize: 18
                color: pbControl.isActive ? pbControl.btnColor : "#7f849c"
                Layout.leftMargin: 2
            }
            Text {
                text: pbControl.label
                font.family: root ? root.fontFamily : "sans-serif"
                font.pixelSize: 13
                color: pbControl.isActive ? pbControl.btnColor : "#cdd6f4"
                font.bold: pbControl.isActive
                Layout.fillWidth: true
            }
            Rectangle {
                width: 6; height: 6; radius: 3
                color: pbControl.btnColor
                visible: pbControl.isActive
                Layout.rightMargin: 2
            }
        }

        background: Rectangle {
            implicitWidth: 200
            implicitHeight: 44
            radius: 8
            color: pbControl.hovered ? "#313244" : "transparent"
            border.color: pbControl.isActive ? pbControl.btnColor : "transparent"
            border.width: pbControl.isActive ? 1 : 0
        }
    }
}
