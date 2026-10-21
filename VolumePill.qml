// VolumePill.qml - master volume pill (layout: components/ValuePill.qml).
// Left click: VolumeSlider popup. Middle click: connect/disconnect BT headphones
// (MAC in scripts/bt-config.sh). Right click: mute. Scroll: volume up/down by volumeStep.

import Quickshell.Io
import QtQuick
import "components"

ValuePill {
    id: volumePill

    // ── Tweakables ──
    property string volumeStep: "1%"            // scroll step, any wpctl amount ("5%", "0.02")
    property color mutedColor: "#555555"        // pill color when muted
    property color headphonesColor: "#b57bac"   // pill color on bluetooth output
    property color speakersColor: "#7b8fb5"     // pill color otherwise
    property color normalTextColor: "black"
    property color mutedTextColor: "#aaaaaa"
    property string mutedIcon: "󰖁"
    property string headphonesIcon: "󰋋"
    property string speakersIcon: "󰕾"
    property string mutedText: "muted"          // shown instead of the number when muted
    minWidth: 55

    color: root.volumeMuted      ? mutedColor :
           root.headphonesActive ? headphonesColor : speakersColor
    icon: root.volumeMuted      ? mutedIcon :
          root.headphonesActive ? headphonesIcon : speakersIcon
    valueText: root.volumeMuted ? mutedText : root.volumeLevel
    textColor: root.volumeMuted ? mutedTextColor : normalTextColor

    Process { id: muteProcess;     command: ["wpctl", "set-mute",   "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volUpProcess;    command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumePill.volumeStep + "+"] }
    Process { id: volDownProcess;  command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumePill.volumeStep + "-"] }
    Process { id: btToggleProcess; command: ["bash", root.scriptsDir + "/volume-toggle-bt.sh"] }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                muteProcess.running = true
            else if (mouse.button === Qt.MiddleButton)
                btToggleProcess.running = true
            else if (mouse.button === Qt.LeftButton)
                root.activeVolumeScreen = (root.activeVolumeScreen === screen ? null : screen)
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) volUpProcess.running = true
            else volDownProcess.running = true
        }
    }
}
