// YtmPanel.qml - big "now playing" card that drops down from YtmPill.
// Cover art, title, artist, elapsed / total time and a progress bar. Click anywhere on it to close.
// Opens at root.ytmPillLeftX (set by Bar.qml), same width as the pill (root.ytmWidth).
// Rough edges are listed in .claude/TODO.md.

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: ytmPanel
    property var root

    // ── Tweakables ──
    readonly property int expandedHeight: 290   // full card height
    property int artHeight: 180                 // cover art height
    property int openAnimMs: 300                // drop-down animation length
    property color cardColor: "#ff4444"
    property color artPlaceholder: "#cc2222"    // behind the cover while it loads
    property color titleColor: "black"
    property color artistColor: "#1a0000"
    property int titleFontSize: 13
    property int artistFontSize: 11
    property int timeFontSize: 10
    property color progressFill: root.colBlue
    property color progressTrack: root.colSurface

    anchors { top: true; left: true }
    margins.top: -root.barHeight + 4        // pulls the card up so it overlaps the pill
    margins.left: root.ytmPillLeftX
    width: root.ytmWidth
    // Always the full height when visible so clipping works; 0 would prevent layout
    height: expandedHeight
    color: "transparent"
    visible: root.activeYtmScreen === screen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Replay the drop-down animation every time it opens
    onVisibleChanged: {
        if (visible) {
            inner.height = 0
            expandAnim.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activeYtmScreen = null
    }

    // Visible card (its height animates from 0 to expandedHeight)
    Rectangle {
        id: inner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        height: 0
        color: ytmPanel.cardColor
        radius: root.pillRadius

        NumberAnimation {
            id: expandAnim
            target: inner
            property: "height"
            from: 0
            to: ytmPanel.expandedHeight
            duration: ytmPanel.openAnimMs
            easing.type: Easing.OutCubic
        }

        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 8

            // Album art
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: ytmPanel.artHeight

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    clip: true
                    color: ytmPanel.artPlaceholder

                    Image {
                        anchors.fill: parent
                        source: root.ytmArt
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                }
            }

            // Song title
            Text {
                Layout.fillWidth: true
                text: root.ytmTitle
                color: ytmPanel.titleColor
                font.pixelSize: ytmPanel.titleFontSize
                font.family: root.fontFamily
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // Artist
            Text {
                Layout.fillWidth: true
                text: root.ytmArtist
                color: ytmPanel.artistColor
                font.pixelSize: ytmPanel.artistFontSize
                font.family: root.fontFamily
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // Time labels + progress bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                // elapsed (left) ... total (right)
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ytmPanel.formatTime(root.ytmProgressSeconds)
                        color: ytmPanel.artistColor
                        font.pixelSize: ytmPanel.timeFontSize
                        font.family: root.fontFamily
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: ytmPanel.formatTime(root.ytmDuration)
                        color: ytmPanel.artistColor
                        font.pixelSize: ytmPanel.timeFontSize
                        font.family: root.fontFamily
                    }
                }

                // Progress bar, same geometry as the VolumeSlider master track
                Item {
                    Layout.fillWidth: true
                    height: 12
                    property real prog: root.ytmDuration > 0
                        ? Math.max(0, Math.min(1, root.ytmProgressSeconds / root.ytmDuration))
                        : 0
                    property real hx: prog * (width - 4)

                    Rectangle {
                        height: parent.height; anchors.left: parent.left
                        width: Math.max(0, parent.hx - 4)
                        color: ytmPanel.progressFill; radius: 3
                    }
                    Rectangle {
                        height: parent.height; x: parent.hx + 8
                        width: Math.max(0, parent.width - x)
                        color: ytmPanel.progressTrack; radius: 3
                    }
                    Rectangle {
                        x: parent.hx; y: 0
                        width: 4; height: parent.height; radius: 2
                        color: "#ffffff"
                    }
                }
            }
        }
    }

    // Seconds -> "m:ss"
    function formatTime(secs) {
        if (!secs || secs <= 0) return "0:00"
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        var rem = s % 60
        return m + ":" + (rem < 10 ? "0" : "") + rem
    }
}
