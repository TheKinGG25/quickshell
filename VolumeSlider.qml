// VolumeSlider.qml - volume popup, top right. Opened by left-clicking VolumePill, closes on mouse leave.
// Top: master volume (wpctl). Below: one slider per app playing audio (pactl, list from root.appVolumes).
// The slider itself (look, drag, scroll) is components/VolumeBarSlider.qml.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

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
    property int trackHeight: 12
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

        PopupCard {
            root: volumeWindow.root
            width: volumeWindow.cardWidth
            height: contentColumn.implicitHeight + 20
            anchors.top: parent.top
            anchors.right: parent.right
            radius: volumeWindow.cardRadius

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
                    VolumeBarSlider {
                        id: masterSlider
                        Layout.fillWidth: true
                        trackHeight: volumeWindow.trackHeight
                        wheelStep: volumeWindow.wheelStep
                        fillColor: volumeWindow.masterFill
                        emptyColor: root.colSurface
                        pressedHandleColor: root.colRosewater

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
                        VolumeBarSlider {
                            id: appSlider
                            Layout.fillWidth: true
                            trackHeight: volumeWindow.trackHeight
                            wheelStep: volumeWindow.wheelStep
                            fillColor: volumeWindow.appFill
                            emptyColor: root.colSurface
                            pressedHandleColor: root.colRosewater
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
                        }
                    }
                }
            }
        }
    }

    // Shows the hover area while root.debugPopups is on
    HoverDebug {
        anchors.fill: parent
        root: volumeWindow.root
        label: "volume"
    }
}
