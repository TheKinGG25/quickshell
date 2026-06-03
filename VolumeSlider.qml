import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls

PanelWindow {
    property var root

    anchors { top: true; right: true }
    margins.top: 30
    margins.right: 2
    width: 180
    height: 44
    color: "transparent"
    visible: root.volumeSliderVisible
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#DD1e1e2e"

        Slider {
            id: slider
            anchors.centerIn: parent
            width: parent.width - 16
            from: 0; to: 100
            stepSize: 1
            snapMode: Slider.SnapAlways

            Component.onCompleted: value = root.volumeLevel

            Connections {
                target: root
                function onVolumeLevelChanged() {
                    if (!slider.pressed)
                        slider.value = root.volumeLevel
                }
            }

            Process {
                id: setVolumeProcess
                command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(slider.value) + "%"]
            }

            onMoved: {
                setVolumeProcess.running = false
                setVolumeProcess.running = true
            }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: "#444444"

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: "#7b8fb5"
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 16; height: 16
                radius: 8
                color: "#ffffff"
            }
        }
    }
}
