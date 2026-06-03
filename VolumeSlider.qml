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
    visible: root.activeVolumeScreen === screen
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: root.activeVolumeScreen = null

        Rectangle {
            width: 260
            height: contentColumn.implicitHeight + 20
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.rightMargin: 0

            radius: 12
            color: "#DD11111b"
            border.color: "#313244"
            border.width: 1

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // Master Volume
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

                        background: Item {
                            implicitHeight: 12
                            width: parent.availableWidth
                            anchors.verticalCenter: parent.verticalCenter
                            property real handleX: masterSlider.visualPosition * (parent.width - 4)
                            Rectangle {
                                height: parent.height
                                anchors.left: parent.left
                                width: Math.max(0, parent.handleX - 4)
                                color: "#89b4fa"
                                radius: 3
                            }
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
                            width: 4; height: 12; radius: 2
                            color: parent.pressed ? "#f5e0dc" : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) masterSlider.value += 1
                                else masterSlider.value -= 1
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

                            Binding {
                                target: appSlider
                                property: "value"
                                value: modelData.volume
                                when: !appSlider.pressed
                            }

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
                                Rectangle {
                                    height: parent.height
                                    anchors.left: parent.left
                                    width: Math.max(0, parent.handleX - 4)
                                    color: "#cba6f7"
                                    radius: 3
                                }
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
                                width: 4; height: 10; radius: 2
                                color: parent.pressed ? "#f5e0dc" : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) appSlider.value += 1
                                    else appSlider.value -= 1
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
