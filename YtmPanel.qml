import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: ytmPanel
    property var root

    readonly property int expandedHeight: 290

    anchors { top: true; left: true }
    margins.top: -root.barHeight + 4
    margins.left: root.ytmPillLeftX
    width: 280
    // Always the full height when visible so clipping works; 0 would prevent layout
    height: expandedHeight
    color: "transparent"
    visible: root.activeYtmScreen === screen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

    Rectangle {
        id: inner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        height: 0
        color: "#ff4444"
        radius: 6

        NumberAnimation {
            id: expandAnim
            target: inner
            property: "height"
            from: 0
            to: ytmPanel.expandedHeight
            duration: 300
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
                Layout.preferredHeight: 180

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    clip: true
                    color: "#cc2222"

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
                color: "black"
                font.pixelSize: 13
                font.family: root.fontFamily
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // Artist
            Text {
                Layout.fillWidth: true
                text: root.ytmArtist
                color: "#1a0000"
                font.pixelSize: 11
                font.family: root.fontFamily
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            // Time labels + progress bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ytmPanel.formatTime(root.ytmProgressSeconds)
                        color: "#1a0000"
                        font.pixelSize: 10
                        font.family: root.fontFamily
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: ytmPanel.formatTime(root.ytmDuration)
                        color: "#1a0000"
                        font.pixelSize: 10
                        font.family: root.fontFamily
                    }
                }

                // Progress bar — same geometry as VolumeSlider master track
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
                        color: "#89b4fa"; radius: 3
                    }
                    Rectangle {
                        height: parent.height; x: parent.hx + 8
                        width: Math.max(0, parent.width - x)
                        color: "#313244"; radius: 3
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

    function formatTime(secs) {
        if (!secs || secs <= 0) return "0:00"
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        var rem = s % 60
        return m + ":" + (rem < 10 ? "0" : "") + rem
    }
}
