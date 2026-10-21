import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    property var root
    property var screen

    property color pillColor: root.volumeMuted      ? "#555555" :
                              root.headphonesActive ? "#b57bac" : "#7b8fb5"

    property string icon: root.volumeMuted      ? "󰖁" :
                          root.headphonesActive ? "󰋋" : "󰕾"

    width: Math.max(number.implicitWidth + icon_class.implicitWidth + 10, 55)
    height: 22
    radius: 6
    color: pillColor

    Process { id: muteProcess;     command: ["wpctl", "set-mute",   "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: volUpProcess;    command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1%+"] }
    Process { id: volDownProcess;  command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1%-"] }
    Process { id: btToggleProcess; command: ["bash", root.scriptsDir + "/volume-toggle-bt.sh"] }
    
    Text {
        id:number
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.volumeMuted ? "muted" : root.volumeLevel
        color: root.volumeMuted ? "#aaaaaa" : "black"
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }
    
    Text {
        id:icon_class
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: icon
        color: root.volumeMuted ? "#aaaaaa" : "black"
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
