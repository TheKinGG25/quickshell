// PowerMenu.qml - shutdown / restart / sleep / lock popup, centered under the bar.
// Opened by middle-clicking the clock (Center.qml), closes when the mouse leaves.
// Add, remove or reorder buttons in `buttons` below.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

PanelWindow {
    id: powerWindow
    property var root

    // ── Tweakables ──
    // One entry per button. icon: Nerd Font code point (https://www.nerdfonts.com/cheat-sheet),
    // color: icon + hover border color, command: what runs on click.
    property var buttons: [
        { icon: "",    label: "Shutdown", color: root.colRed,    command: ["systemctl", "poweroff"] },
        { icon: "",    label: "Restart",  color: root.colPeach,  command: ["systemctl", "reboot"] },
        { icon: "\u{f04b2}", label: "Sleep",    color: root.colYellow, command: ["systemctl", "suspend"] },
        { icon: "\u{f033e}", label: "Lock",     color: root.colBlue,   command: ["loginctl", "lock-session"] }
    ]
    property int buttonSize: 90         // each button is a square of this size
    property int buttonSpacing: 28      // gap between buttons
    property int iconSize: 32
    property int labelSize: 12
    property int cardRadius: 16
    property int cardPadding: 40        // extra space around the button row inside the card
    property int topOffset: 30          // distance from the screen top (just below the bar)

    anchors { top: true; left: true; right: true }

    margins.top: 0 // Start from screen top to cover the bar area with buffer

    // Window width includes side buffers (the invisible margin keeps the mouse "inside" a bit longer)
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

        PopupCard {
            root: powerWindow.root
            width: contentRow.implicitWidth + powerWindow.cardPadding
            height: contentRow.implicitHeight + powerWindow.cardPadding
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: powerWindow.topOffset // Position the visible menu right below the bar

            radius: powerWindow.cardRadius

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: powerWindow.buttonSpacing

                Repeater {
                    model: powerWindow.buttons
                    delegate: Button {
                        id: control
                        onClicked: {
                            actionProc.command = modelData.command
                            actionProc.running = false
                            actionProc.running = true
                        }

                        // Icon on top, label below
                        contentItem: ColumnLayout {
                            spacing: 8
                            Text {
                                text: modelData.icon
                                font.family: root.fontFamily
                                font.pixelSize: powerWindow.iconSize
                                color: modelData.color
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modelData.label
                                font.family: root.fontFamily
                                font.pixelSize: powerWindow.labelSize
                                color: root.colText
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        background: Rectangle {
                            implicitWidth: powerWindow.buttonSize
                            implicitHeight: powerWindow.buttonSize
                            radius: 12
                            color: control.hovered ? root.colSurface : "transparent"
                            border.color: control.hovered ? modelData.color : "transparent"
                            border.width: 1
                        }
                    }
                }
            }
        }
    }

    // Runs the command of whichever button was clicked
    Process { id: actionProc }

    // Shows the hover area while root.debugPopups is on
    HoverDebug {
        anchors.fill: parent
        root: powerWindow.root
        label: "power"
    }
}
