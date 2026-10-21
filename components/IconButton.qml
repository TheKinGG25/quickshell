// IconButton.qml - square button showing one Nerd Font icon, with hover and "active" colors.
// Used by the YtmPanel player controls and its side column.
// Set `glyph` (and `activeGlyph` / `active` for toggles like "liked"), `onClicked`, and the colors.
// Hover / press use a "state layer": a thin overlay of the icon color on top of baseColor, so no hover color is needed.
// Not called `icon`: Button already has a built-in (FINAL) `icon` property that cannot be redefined.

import QtQuick
import QtQuick.Controls

Button {
    id: btn

    property string glyph: ""
    property string activeGlyph: ""                 // shown instead of `glyph` while active (empty = same glyph)
    property bool active: false                     // e.g. liked / repeat on
    property int size: 44
    property int iconSize: 20
    property int cornerRadius: 10
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color baseColor: "#33000000"
    property real hoverOpacity: 0.12                // state layer strength while hovered
    property real pressedOpacity: 0.20              // and while pressed
    property color iconColor: "black"
    property color activeColor: "white"             // icon color while active

    implicitWidth: size
    implicitHeight: size
    padding: 0
    Accessible.name: text                           // text is the tooltip-style label, not drawn

    contentItem: Text {
        text: btn.active && btn.activeGlyph !== "" ? btn.activeGlyph : btn.glyph
        color: btn.active ? btn.activeColor : btn.iconColor
        font.family: btn.fontFamily
        font.pixelSize: btn.iconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: btn.cornerRadius
        color: btn.baseColor

        // State layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btn.iconColor
            opacity: btn.down ? btn.pressedOpacity : btn.hovered ? btn.hoverOpacity : 0
        }
    }
}
