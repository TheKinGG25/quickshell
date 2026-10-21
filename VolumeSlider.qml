// VolumeSlider.qml - volume popup, top right. Opened by left-clicking VolumePill, closes on mouse leave.
// Top: master volume (wpctl). Below: one slider per app playing audio (pactl, list from root.appVolumes).
// Sliders support drag and scroll (scroll step: wheelStep).

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: volumeWindow
    property var root

    // ── Tweakables ──
    property int cardWidth: 260
    property int cardRadius: 12
    property int wheelStep: 1                   // % per scroll notch on any slider
    property string masterLabel: "Master Volume: "
    property color masterFill: root.colBlue     // filled part of the master slider
    property color appFill: root.colMauve       // filled part of the app sliders
    property int masterTrackHeight: 12
    property int appTrackHeight: 10
    property int appNameMaxWidth: 230           // long app names are cut with "..."

    anchors { top: true; right: true }
    margins.top: 0
    margins.right: 0
    implicitWidth: cardWidth + 60                       // invisible margin around the card
    implicitHeight: contentColumn.implicitHeight + 80
    color: "transparent"
    visible: root.activeVolumeScreen === screen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: root.activeVolumeScreen = null

        // Visible card
        Rectangle {
            width: volumeWindow.cardWidth
            height: contentColumn.implicitHeight + 20
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.rightMargin: 0

            radius: volumeWindow.cardRadius
            color: root.popupBg
            border.color: root.popupBorder
            border.width: 1

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // ── Master Volume ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: volumeWindow.masterLabel + Math.round(masterSlider.value)
                        color: root.colText
                        font.pixelSize: 12
                        font.family: root.fontFamily
                        font.bold: true
                    }
                    Slider {
                        id: masterSlider
                        Layout.fillWidth: true
                        implicitHeight: 12
                        from: 0; to: 100
                        stepSize: 1
                        snapMode: Slider.SnapAlways

                        // Follows the live volume except while dragging (root.volumeLevel updates within ~30ms)
                        Binding {
                            target: masterSlider
                            property: "value"
                            value: root.volumeLevel
                            when: !masterSlider.pressed
                        }

                        onMoved: {
                            setMasterVol.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(value) + "%"]
                            setMasterVol.running = false
                            setMasterVol.running = true
                        }

                        Process { id: setMasterVol }

                        // Track: filled part | gap | empty part
                        background: Item {
                            implicitHeight: volumeWindow.masterTrackHeight
                            width: parent.availableWidth
                            anchors.verticalCenter: parent.verticalCenter
                            property real handleX: masterSlider.visualPosition * (parent.width - 4)
                            Rectangle {
                                height: parent.height
                                anchors.left: parent.left
                                width: Math.max(0, parent.handleX - 4)
                                color: volumeWindow.masterFill
                                radius: 3
                            }
                            Rectangle {
                                height: parent.height
                                x: parent.handleX + 8
                                width: Math.max(0, parent.width - x)
                                color: root.colSurface
                                radius: 3
                            }
                        }

                        // Thin vertical handle
                        handle: Rectangle {
                            x: parent.visualPosition * (parent.availableWidth - width)
                            y: (parent.height - height) / 2
                            width: 4; height: volumeWindow.masterTrackHeight; radius: 2
                            color: parent.pressed ? root.colRosewater : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) masterSlider.value += volumeWindow.wheelStep
                                else masterSlider.value -= volumeWindow.wheelStep
                                masterSlider.moved()
                            }
                        }
                    }
                }

                // ── App Volumes ── one block per entry in root.appVolumes
                Repeater {
                    model: root.appVolumes
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: modelData.name + ": " + Math.round(appSlider.value)
                            color: root.colSubtext
                            font.pixelSize: 11
                            font.family: root.fontFamily
                            elide: Text.ElideRight
                            Layout.maximumWidth: volumeWindow.appNameMaxWidth
                        }
                        Slider {
                            id: appSlider
                            Layout.fillWidth: true
                            implicitHeight: 12
                            from: 0; to: 100
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            // Plain initial value, not a Binding: appVolumes is not polled while this
                            // panel is open, so re-applying modelData.volume on release would snap
                            // the handle back to the stale value. The delegate is rebuilt on the next poll.
                            value: modelData.volume

                            onMoved: {
                                setAppVol.command = ["pactl", "set-sink-input-volume", modelData.id, Math.round(value) + "%"]
                                setAppVol.running = false
                                setAppVol.running = true
                            }

                            Process { id: setAppVol }

                            // Track: filled part | gap | empty part
                            background: Item {
                                implicitHeight: volumeWindow.appTrackHeight
                                width: parent.availableWidth
                                anchors.verticalCenter: parent.verticalCenter
                                property real handleX: appSlider.visualPosition * (parent.width - 4)
                                Rectangle {
                                    height: parent.height
                                    anchors.left: parent.left
                                    width: Math.max(0, parent.handleX - 4)
                                    color: volumeWindow.appFill
                                    radius: 3
                                }
                                Rectangle {
                                    height: parent.height
                                    x: parent.handleX + 8
                                    width: Math.max(0, parent.width - x)
                                    color: root.colSurface
                                    radius: 3
                                }
                            }

                            // Thin vertical handle
                            handle: Rectangle {
                                x: parent.visualPosition * (parent.availableWidth - width)
                                y: (parent.height - height) / 2
                                width: 4; height: volumeWindow.appTrackHeight; radius: 2
                                color: parent.pressed ? root.colRosewater : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) appSlider.value += volumeWindow.wheelStep
                                    else appSlider.value -= volumeWindow.wheelStep
                                    appSlider.moved()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
