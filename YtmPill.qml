// YtmPill.qml - "now playing" pill (YouTube Music Desktop).
// Shows cover thumbnail, title, artist and a thin progress line. Hidden when nothing is playing.
// Left click: toggle YtmPanel. Scroll: app volume up / down. Data: root.ytm* in shell.qml. Width: root.ytmWidth.

import QtQuick

Rectangle {
    id: ytmPill
    property var root
    property var screen

    // ── Tweakables ──
    property color pillColor: "#ff4444"             // pill background
    property color titleColor: "black"
    property color artistColor: "#1a0000"
    property color thumbPlaceholder: "#333333"      // shown behind the cover while it loads
    property int titleFontSize: 15
    property int artistFontSize: 12
    property int thumbSize: 16                      // cover thumbnail (px)
    property real artistMaxShare: 0.6               // artist text may take at most this share of the width
    property int progressHeight: 2                  // progress line at the bottom
    property color progressTrack: Qt.rgba(0, 0, 0, 0.3)
    property color progressFill: Qt.rgba(0, 0, 0, 0.7)

    visible: root.ytmAvailable
    // Hidden while YtmPanel is open on this screen: the panel draws a copy that grows into the player
    opacity: root.ytmPanelScreen !== null && root.ytmPanelScreen === screen ? 0 : 1
    width: root.ytmWidth
    height: root.pillHeight
    radius: root.pillRadius
    clip: true
    color: pillColor

    // Cover thumbnail
    Rectangle {
        id: artThumb
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.top: parent.top
        anchors.topMargin: (parent.height - height) / 2
        width: ytmPill.thumbSize
        height: ytmPill.thumbSize
        radius: 2
        clip: true
        color: ytmPill.thumbPlaceholder

        Image {
            anchors.fill: parent
            source: root.ytmArt
            fillMode: Image.PreserveAspectCrop
        }
    }

    // Title (left, bold) and artist (right)
    Item {
        anchors.left: artThumb.right
        anchors.leftMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top
        height: parent.height

        Text {
            id: songText
            anchors.left: parent.left
            anchors.right: artistText.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.ytmTitle
            elide: Text.ElideRight
            color: ytmPill.titleColor
            font.pixelSize: ytmPill.titleFontSize
            font.family: root.fontFamily
            font.bold: true
        }

        Text {
            id: artistText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * ytmPill.artistMaxShare)
            text: root.ytmArtist
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            color: ytmPill.artistColor
            font.pixelSize: ytmPill.artistFontSize
            font.family: root.fontFamily
        }
    }

    // Progress line: track, then filled part
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: ytmPill.progressHeight
        color: ytmPill.progressTrack
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * (root.ytmProgress / 100)
        height: ytmPill.progressHeight
        color: ytmPill.progressFill
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.activeYtmScreen = (root.activeYtmScreen === screen ? null : screen)
        }
        // Scroll: the YouTube Music app's own volume (step: root.ytmVolumeStep in shell.qml)
        onWheel: wheel => {
            root.ytmCommand(wheel.angleDelta.y > 0 ? "volume-up" : "volume-down", { amount: root.ytmVolumeStep })
        }
    }
}
