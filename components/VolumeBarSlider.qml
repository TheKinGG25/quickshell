// VolumeBarSlider.qml - 0..100 slider with a SliderTrack background, a thin handle and scroll support.
// Used for the master and per-app sliders in VolumeSlider.qml.
// React to changes with onMoved (fires on drag and on scroll); read the value with `value`.

import QtQuick
import QtQuick.Controls

Slider {
    id: control

    property color fillColor: "#89b4fa"
    property color emptyColor: "#313244"
    property color handleColor: "#ffffff"
    property color pressedHandleColor: "#f5e0dc"    // handle while dragging
    property int trackHeight: 12
    property int wheelStep: 1                       // value change per scroll notch

    from: 0; to: 100
    stepSize: 1
    snapMode: Slider.SnapAlways

    background: SliderTrack {
        implicitHeight: control.trackHeight
        width: control.availableWidth
        anchors.verticalCenter: parent.verticalCenter
        position: control.visualPosition
        fillColor: control.fillColor
        emptyColor: control.emptyColor
    }

    // Thin vertical handle
    handle: Rectangle {
        x: control.visualPosition * (control.availableWidth - width)
        y: (control.height - height) / 2
        width: 4; height: control.trackHeight; radius: 2
        color: control.pressed ? control.pressedHandleColor : control.handleColor
    }

    // Scroll wheel: step the value and report it like a drag
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) control.value += control.wheelStep
            else control.value -= control.wheelStep
            control.moved()
        }
    }
}
