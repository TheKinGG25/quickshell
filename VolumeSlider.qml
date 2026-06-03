import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: volumeWindow
    property var root

    anchors { top: true; right: true }
    margins.top: 0
    margins.right: 0
    width: 320
    height: contentColumn.implicitHeight + 80
    color: "transparent"
    visible: root.volumeSliderVisible
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Large hover area to prevent accidental hiding
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: {
            root.volumeSliderVisible = false
        }

        // DEBUG SHAPE: Visualizes the area that keeps the window open
        Rectangle {
            anchors.fill: parent
            color: "#44ff0000" // Transparent red
            border.color: "red"
            border.width: 1
            z: -1

            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                text: "DEBUG: Hover Area"
                color: "red"
                font.pixelSize: 10
            }
        }

        // Visible container
        Rectangle {
            width: 260
            height: contentColumn.implicitHeight + 20
            // Positioned exactly at the bottom of the 30px bar
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.rightMargin: 0

            radius: 12
            color: "#DD11111b"
            border.color: "#313244"
            border.width: 1

            // Catch events inside the visible box
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onPressed: (mouse) => mouse.accepted = false
            }

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // Main Volume
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: "Master Volume: " + Math.round(masterSlider.value)
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        font.family: root.fontFamily
                        font.bold: true
                    }
                    Slider {
                        id: masterSlider
                        Layout.fillWidth: true
                        implicitHeight: 24
                        from: 0; to: 100
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: root.volumeLevel

                        onMoved: {
                            setMasterVol.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(value) + "%"]
                            setMasterVol.running = false
                            setMasterVol.running = true
                        }

                        Process { id: setMasterVol }

                        background: Item {
                            implicitHeight: 12
                            width: parent.availableWidth
                            anchors.verticalCenter: parent.verticalCenter

                            property real handleX: masterSlider.visualPosition * (parent.width - 4)

                            // Left Bar
                            Rectangle {
                                height: parent.height
                                anchors.left: parent.left
                                width: Math.max(0, parent.handleX - 4)
                                color: "#89b4fa"
                                radius: 3
                            }

                            // Right Bar
                            Rectangle {
                                height: parent.height
                                x: parent.handleX + 8
                                width: Math.max(0, parent.width - x)
                                color: "#313244"
                                radius: 3
                            }
                        }

                        handle: Rectangle {
                            x: parent.visualPosition * (parent.availableWidth - width)
                            y: (parent.height - height) / 2
                            width: 4
                            height: 12
                            radius: 2
                            color: parent.pressed ? "#f5e0dc" : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) masterSlider.value += 2
                                else masterSlider.value -= 2
                                masterSlider.moved()
                            }
                        }
                    }
                }

                // App Volumes
                Repeater {
                    model: root.appVolumes
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: modelData.name + ": " + Math.round(appSlider.value)
                            color: "#a6adc8"
                            font.pixelSize: 11
                            font.family: root.fontFamily
                            elide: Text.ElideRight
                            Layout.maximumWidth: 230
                        }
                        Slider {
                            id: appSlider
                            Layout.fillWidth: true
                            implicitHeight: 20
                            from: 0; to: 100
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            value: modelData.volume

                            onMoved: {
                                setAppVol.command = ["pactl", "set-sink-input-volume", modelData.id, Math.round(value) + "%"]
                                setAppVol.running = false
                                setAppVol.running = true
                            }

                            Process { id: setAppVol }

                            background: Item {
                                implicitHeight: 10
                                width: parent.availableWidth
                                anchors.verticalCenter: parent.verticalCenter

                                property real handleX: appSlider.visualPosition * (parent.width - 4)

                                // Left Bar
                                Rectangle {
                                    height: parent.height
                                    anchors.left: parent.left
                                    width: Math.max(0, parent.handleX - 4)
                                    color: "#cba6f7"
                                    radius: 3
                                }

                                // Right Bar
                                Rectangle {
                                    height: parent.height
                                    x: parent.handleX + 8
                                    width: Math.max(0, parent.width - x)
                                    color: "#313244"
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: parent.visualPosition * (parent.availableWidth - width)
                                y: (parent.height - height) / 2
                                width: 4
                                height: 10
                                radius: 2
                                color: parent.pressed ? "#f5e0dc" : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) appSlider.value += 2
                                    else appSlider.value -= 2
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
