// Overview.qml - exploded view of THIS screen's workspace grid, Hyprland only, one per screen.
// All its keys live in Hyprland (~/.config/hypr: grid.lua + the "overview" submap in keybinds.lua):
// Meta+Tab opens it, arrows move through the grid, Ctrl+= / Ctrl+- zoom, Enter / Escape /
// Meta+Tab close it, every other key is swallowed. This file only draws root.hyprGrid.overview.
// Columns are n = 1..6, rows are this monitor's m for that n. Each column is shifted so the
// workspace its bar label shows ([n,m], root.gridM) sits on the middle row; empty workspaces
// are not drawn. Windows are live previews (ScreencopyView). Clicking a workspace goes there and closes the view.
// The window takes no keyboard focus: Hyprland's submap handles the keyboard.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: overview
    property var root

    // ── Tweakables ──
    property color backdropColor: "#e6101018"              // behind the grid
    property color cellColor: "#26ffffff"                  // a workspace
    property color currentColor: overview.root.colBlue     // border of the workspace this monitor is on
    property color hoverColor: overview.root.colOverlay    // border under the mouse
    property color labelColor: overview.root.colText
    property color labelBg: "#99000000"
    property int gap: 28                // between workspaces, in px at every zoom level
    property int cellRadius: 10
    property int currentBorder: 3
    property int animMs: 220            // camera glide and zoom

    readonly property var grid: root ? root.hyprGrid : null
    readonly property bool open: !!(root && root.hyprland && grid && grid.overview && grid.overview.open)
    readonly property var me: grid && screen && grid.screens ? grid.screens[screen.name] : null
    readonly property var hmon: open && screen ? Hyprland.monitorFor(screen) : null
    readonly property int curN: grid ? grid.n : 1
    readonly property int curM: me ? me.m[curN - 1] : 1

    // `zoom` workspaces fit across the screen (100% = 3); each keeps the screen's shape
    readonly property real screenW: screen ? screen.width : 1
    readonly property real screenH: screen ? screen.height : 1
    readonly property real zoomCount: grid && grid.overview ? grid.overview.zoom : 3
    property real cellW: (screenW - gap * (zoomCount + 1)) / zoomCount
    Behavior on cellW { NumberAnimation { duration: overview.animMs; easing.type: Easing.OutCubic } }
    readonly property real cellH: cellW * screenH / screenW
    readonly property real scaleF: cellW / screenW

    visible: open && me !== null
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None   // keys stay with Hyprland and the focused app
    WlrLayershell.namespace: "quickshell-overview"

    function windowsOn(wsId) {
        return Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === wsId)
    }

    // Window positions come from lastIpcObject, which only updates on refreshToplevels()
    onOpenChanged: if (open) Hyprland.refreshToplevels()
    Connections {
        target: Hyprland
        enabled: overview.open
        function onRawEvent(event) { refreshTimer.restart() }
    }
    Timer { id: refreshTimer; interval: 60; onTriggered: Hyprland.refreshToplevels() }

    Rectangle {
        anchors.fill: parent
        color: overview.backdropColor
    }

    // The whole grid: the current n in the middle column, every column's bar workspace on the
    // middle row
    Item {
        id: world
        x: overview.screenW / 2 - ((overview.curN - 1) * (overview.cellW + overview.gap) + overview.cellW / 2)
        y: overview.screenH / 2 - overview.cellH / 2
        Behavior on x { NumberAnimation { duration: overview.animMs; easing.type: Easing.OutCubic } }

        Repeater {
            model: overview.me ? overview.me.rows.length : 0
            delegate: Item {
                id: column
                required property int index
                readonly property int n: index + 1
                readonly property int rows: overview.me ? overview.me.rows[index] : 1
                readonly property int barM: overview.me ? overview.me.m[index] : 1
                // Slide the column so [n, barM] lands on the middle row
                y: -(barM - 1) * (overview.cellH + overview.gap)
                Behavior on y { NumberAnimation { duration: overview.animMs; easing.type: Easing.OutCubic } }

                Repeater {
                    model: column.rows
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property int m: index + 1
                        readonly property int wsId: overview.me.index * 10000 + column.n * 1000 + m
                        readonly property var windows: overview.windowsOn(wsId)
                        readonly property bool current: column.n === overview.curN && m === overview.curM
                        visible: windows.length > 0     // empty workspaces are left out
                        x: (column.n - 1) * (overview.cellW + overview.gap)
                        y: index * (overview.cellH + overview.gap)
                        width: overview.cellW
                        height: overview.cellH

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: overview.cellRadius
                            color: overview.cellColor

                            Repeater {
                                model: cell.windows
                                delegate: ScreencopyView {
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject
                                    readonly property bool known: !!(ipc && ipc.at && ipc.size && overview.hmon)
                                    visible: known
                                    x: known ? (ipc.at[0] - overview.hmon.x) * overview.scaleF : 0
                                    y: known ? (ipc.at[1] - overview.hmon.y) * overview.scaleF : 0
                                    width: known ? ipc.size[0] * overview.scaleF : 0
                                    height: known ? ipc.size[1] * overview.scaleF : 0
                                    z: known && ipc.floating ? 1 : 0
                                    captureSource: overview.open ? modelData.wayland : null
                                    live: overview.open
                                    constraintSize: Qt.size(Math.max(1, width), Math.max(1, height))
                                }
                            }
                        }

                        // Border on top of the previews (the clipped content would cover it)
                        Rectangle {
                            anchors.fill: parent
                            radius: overview.cellRadius
                            color: "transparent"
                            border.width: cell.current ? overview.currentBorder : (mouse.containsMouse ? 1 : 0)
                            border.color: cell.current ? overview.currentColor : overview.hoverColor
                        }

                        Rectangle {
                            anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
                            width: label.implicitWidth + 12
                            height: label.implicitHeight + 4
                            radius: 4
                            color: overview.labelBg
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: "[" + column.n + "," + cell.m + "]"
                                color: overview.labelColor
                                font.family: overview.root.fontFamily
                                font.pixelSize: overview.root.fontSize - 2
                                font.bold: cell.current
                            }
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overview.root.gridGo(overview.screen.name, column.n, cell.m)
                        }
                    }
                }
            }
        }
    }

    // Clicking the backdrop (outside any workspace) just closes the view
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: overview.root.closeOverview()
    }
}
