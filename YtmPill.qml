import Quickshell.Io
import QtQuick

Rectangle {
    property var root
    property var screen

    property bool ytmAvailable: false
    property string ytmTitle: ""
    property string ytmArtist: ""
    property string ytmArt: ""
    property real ytmProgress: 0  // 0–100

    visible: ytmAvailable
    width: 250
    height: 22
    radius: 6
    clip: true
    color: "#ff4444"

    function parseData(line) {
        try {
            var d = JSON.parse(line)
            ytmAvailable = d.available === true && !!d.title
            ytmTitle = d.title || ""
            ytmArtist = d.artist || ""
            ytmArt = d.art || ""
            var dur = d.durationSeconds || 0
            var prog = d.progressSeconds || 0
            ytmProgress = dur > 0 ? (prog / dur * 100) : 0
        } catch(e) {
            ytmAvailable = false
        }
    }

    Process {
        id: readProcess
        command: ["cat", "/home/thekingg/.cache/ytmd-now.json"]
        stdout: SplitParser {
            onRead: data => parseData(data)
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: readProcess.running = true
    }

    Rectangle {
        id: artContainer
        anchors.left: parent.left
        anchors.leftMargin: 3
        anchors.top: parent.top
        anchors.topMargin: 3
        width: 16
        height: 16
        radius: 2
        clip: true
        color: "#333333"

        Image {
            anchors.fill: parent
            source: ytmArt
            fillMode: Image.PreserveAspectCrop
        }
    }

    Item {
        anchors.left: artContainer.right
        anchors.leftMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 2
            text: ytmTitle
            elide: Text.ElideRight
            color: "black"
            font.pixelSize: 15
            font.family: root.fontFamily
            font.bold: true
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 2
            text: ytmArtist
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            color: "#1a0000"
            font.pixelSize: 12
            font.family: root.fontFamily
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: Qt.rgba(0, 0, 0, 0.18)
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * (ytmProgress / 100)
        height: 2
        color: Qt.rgba(0, 0, 0, 0.45)
    }
}
