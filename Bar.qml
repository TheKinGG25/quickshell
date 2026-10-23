// Bar.qml - the top bar itself, one per monitor.
// Layout: Left (desktops) | Center (clock, centered) | Right (pills).
// Bar height comes from root.barHeight in shell.qml.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: barWindow
    property var root

    // ── Tweakables ──
    property color barColor: "#30000000"    // bar background (#AARRGGBB, 30 = ~19% opacity)
    property int sideMargin: 8              // gap between screen edge and Left / Right sections
    property int rightTopMargin: 4          // nudges the pills down inside the bar

    anchors { top: true; left: true; right: true }
    implicitHeight: root.barHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: barWindow.barColor

        Left {
            anchors.left: parent.left
            anchors.leftMargin: barWindow.sideMargin
            anchors.verticalCenter: parent.verticalCenter
            root: barWindow.root
            screen: barWindow.screen
        }

        Center {
            anchors.centerIn: parent
            height: parent.height
            root: barWindow.root
            screen: barWindow.screen
        }

        Right {
            id: rightSection
            anchors.right: parent.right
            anchors.rightMargin: barWindow.sideMargin
            anchors.top: parent.top
            anchors.topMargin: barWindow.rightTopMargin
            anchors.verticalCenter: parent.verticalCenter
            root: barWindow.root
            screen: barWindow.screen

            // Tells YtmPanel where the pill row is on THIS screen, so the player can grow
            // out of YtmPill (per screen: each monitor's bar has its own x)
            function publishPillGeom() {
                if (barWindow.screen) barWindow.root.setYtmPillGeom(barWindow.screen.name, x, y)
            }
            onXChanged: publishPillGeom()
            onYChanged: publishPillGeom()
            Component.onCompleted: Qt.callLater(publishPillGeom)
        }
    }
}
