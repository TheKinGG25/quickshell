// SliderTrack.qml - the "filled | gap | handle | gap | empty" bar.
// Used as the background of VolumeBarSlider and as the YtmPanel progress bar.
// Set `position` (0..1) and the colors; the geometry follows.

import QtQuick

Item {
    id: track

    property real position: 0               // 0..1, where the handle sits
    property color fillColor: "#89b4fa"     // part before the handle
    property color emptyColor: "#313244"    // part after the handle
    property bool showHandle: false         // draw the handle here (VolumeBarSlider draws its own, draggable one)
    property color handleColor: "#ffffff"
    property int handleWidth: 4
    property int gap: 4                     // space between the handle and each side of the bar
    property int barRadius: 3

    // left edge of the handle
    readonly property real handleX: position * (width - handleWidth)

    // Filled part
    Rectangle {
        anchors.left: parent.left
        height: parent.height
        width: Math.max(0, track.handleX - track.gap)
        color: track.fillColor
        radius: track.barRadius
    }

    // Empty part
    Rectangle {
        x: track.handleX + track.handleWidth + track.gap
        height: parent.height
        width: Math.max(0, parent.width - x)
        color: track.emptyColor
        radius: track.barRadius
    }

    // Optional handle
    Rectangle {
        visible: track.showHandle
        x: track.handleX
        width: track.handleWidth
        height: parent.height
        radius: 2
        color: track.handleColor
    }
}
