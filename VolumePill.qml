// VolumePill.qml - master volume pill.
// Left click: VolumeSlider popup. Middle click: connect/disconnect BT headphones
// (MAC in scripts/bt-config.sh). Right click: mute. Scroll: volume up/down by volumeStep.

import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: volumePill
    property var root
    property var screen

    // ── Tweakables ──
    property string volumeStep: "1%"            // scroll step, any wpctl amount ("5%", "0.02")
    property color mutedColor: "#555555"        // pill color when muted
    property color headphonesColor: "#b57bac"   // pill color on bluetooth output
    property color speakersColor: "#7b8fb5"     // pill color otherwise
    property color textColor: "black"
    property color mutedTextColor: "#aaaaaa"
    property string mutedIcon: "󰖁"
    property string headphonesIcon: "󰋋"
    property string speakersIcon: "󰕾"
    property string mutedText: "muted"          // shown instead of the number when muted
    property int minWidth: 55

    property color pillColor: root.volumeMuted      ? mutedColor :
                              root.headphonesActive ? headphonesColor : speakersColor

    property string icon: root.volumeMuted      ? mutedIcon :
                          root.headphonesActive ? headphonesIcon : speakersIcon

    width: Math.max(number.implicitWidth + icon_class.implicitWidth + 10, minWidth)
    height: root.pillHeight
    radius: root.pillRadius
    color: pillColor

    Process { id: muteProcess;     command: ["wpctl", "set-mute",   "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volUpProcess;    command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumePill.volumeStep + "+"] }
    Process { id: volDownProcess;  command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumePill.volumeStep + "-"] }
    Process { id: btToggleProcess; command: ["bash", root.scriptsDir + "/volume-toggle-bt.sh"] }

    // Volume number (left)
    Text {
        id:number
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.volumeMuted ? volumePill.mutedText : root.volumeLevel
        color: root.volumeMuted ? volumePill.mutedTextColor : volumePill.textColor
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    // Output icon (right)
    Text {
        id:icon_class
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: icon
        color: root.volumeMuted ? volumePill.mutedTextColor : volumePill.textColor
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

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
