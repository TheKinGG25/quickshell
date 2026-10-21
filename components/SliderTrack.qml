// SliderTrack.qml - the "filled | gap | handle | gap | empty" bar.
// Used as the background of VolumeBarSlider, as the YtmPanel seek bar, and (with `vertical`)
// as the YtmPanel volume slider. Set `position` (0..1) and the colors; the geometry follows.
// Horizontal fills from the left, vertical from the bottom.

import QtQuick

Item {
    id: track

    property real position: 0               // 0..1, where the handle sits
    property bool vertical: false           // fill from the bottom instead of from the left
    property color fillColor: "#89b4fa"     // part before the handle
    property color emptyColor: "#313244"    // part after the handle
    property bool showHandle: false         // draw the handle here (VolumeBarSlider draws its own, draggable one)
    property color handleColor: "#ffffff"
    property int handleWidth: 4             // the handle's size along the bar
    property int gap: 4                     // space between the handle and each side of the bar
    property int barRadius: 3

    // Along the bar: length of the track, and the handle's distance from the filled end
    readonly property real span: vertical ? height : width
    readonly property real handleOffset: position * (span - handleWidth)
    // Lengths of the two pieces, and where the handle's near edge sits (top edge when vertical)
    readonly property real fillLength: Math.max(0, handleOffset - gap)
    readonly property real emptyLength: Math.max(0, span - handleOffset - handleWidth - gap)
    readonly property real handleStart: vertical ? span - handleWidth - handleOffset : handleOffset

    // Filled part: left, or bottom when vertical
    Rectangle {
        x: 0
        y: track.vertical ? track.height - track.fillLength : 0
        width: track.vertical ? track.width : track.fillLength
        height: track.vertical ? track.fillLength : track.height
        color: track.fillColor
        radius: track.barRadius
    }

    // Empty part: right, or top when vertical
    Rectangle {
        x: track.vertical ? 0 : track.handleOffset + track.handleWidth + track.gap
        y: 0
        width: track.vertical ? track.width : track.emptyLength
        height: track.vertical ? track.emptyLength : track.height
        color: track.emptyColor
        radius: track.barRadius
    }

    // Optional handle
    Rectangle {
        visible: track.showHandle
        x: track.vertical ? 0 : track.handleStart
        y: track.vertical ? track.handleStart : 0
        width: track.vertical ? track.width : track.handleWidth
        height: track.vertical ? track.handleWidth : track.height
        radius: 2
        color: track.handleColor
    }
}
