// PowerProfileMenu.qml - performance / balanced / power-saver picker, top right.
// Opened by middle-clicking BatteryPill, closes when the mouse leaves.
// The active profile (root.powerProfile, polled in shell.qml) gets a colored border and dot.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

PanelWindow {
    id: profileWindow
    property var root

    // ── Tweakables ──
    // One entry per profile. profile: name passed to `powerprofilesctl set`.
    // icon: Nerd Font code point (https://www.nerdfonts.com/cheat-sheet).
    property var profiles: [
        { icon: "\u{f140c}", label: "Performance", color: root.colRed,   profile: "performance" },
        { icon: "\u{f140b}", label: "Balanced",    color: root.colGreen, profile: "balanced" },
        { icon: "\u{f0f86}", label: "Power Saver", color: root.colBlue,  profile: "power-saver" }
    ]
    property int cardWidth: 220
    property int cardRadius: 12
    property int rowHeight: 44
    property int iconSize: 18
    property int labelSize: 13

    anchors { top: true; right: true }
    margins.top: 0
    margins.right: 0
    implicitWidth: cardWidth + 20                       // invisible margin around the card
    implicitHeight: contentCol.implicitHeight + 80
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

        PopupCard {
            root: profileWindow.root
            width: profileWindow.cardWidth
            height: contentCol.implicitHeight + 24
            anchors.top: parent.top
            anchors.right: parent.right
            radius: profileWindow.cardRadius

            ColumnLayout {
                id: contentCol
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: profileWindow.profiles
                    delegate: Button {
                        id: pbControl
                        property bool isActive: root && root.powerProfile === modelData.profile

                        Layout.fillWidth: true
                        onClicked: {
                            setProfileProc.command = ["powerprofilesctl", "set", modelData.profile]
                            setProfileProc.running = false
                            setProfileProc.running = true
                            root.powerProfile = modelData.profile    // highlight right away, the poll confirms it
                        }

                        // icon | label | dot (dot only on the active profile)
                        contentItem: RowLayout {
                            spacing: 10

                            Text {
                                text: modelData.icon
                                font.family: root.fontFamily
                                font.pixelSize: profileWindow.iconSize
                                color: pbControl.isActive ? modelData.color : root.colOverlay
                                Layout.leftMargin: 2
                            }
                            Text {
                                text: modelData.label
                                font.family: root.fontFamily
                                font.pixelSize: profileWindow.labelSize
                                color: pbControl.isActive ? modelData.color : root.colText
                                font.bold: pbControl.isActive
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: modelData.color
                                visible: pbControl.isActive
                                Layout.rightMargin: 2
                            }
                        }

                        background: Rectangle {
                            implicitWidth: profileWindow.cardWidth - 20
                            implicitHeight: profileWindow.rowHeight
                            radius: 8
                            color: pbControl.hovered ? root.colSurface : "transparent"
                            border.color: pbControl.isActive ? modelData.color : "transparent"
                            border.width: pbControl.isActive ? 1 : 0
                        }
                    }
                }
            }
        }
    }

    // Runs `powerprofilesctl set <profile>` for whichever row was clicked
    Process { id: setProfileProc }

    // Shows the hover area while root.debugPopups is on
    HoverDebug {
        anchors.fill: parent
        root: profileWindow.root
        label: "power profile"
    }
}
