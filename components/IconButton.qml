// IconButton.qml - square button showing one Nerd Font icon, with hover and "active" colors.
// Used by the YtmPanel player controls and its side column.
// Set `icon` (and `activeIcon` / `active` for toggles like "liked"), `onClicked`, and the colors.

import QtQuick
import QtQuick.Controls

Button {
    id: btn

    property string icon: ""
    property string activeIcon: ""                  // shown instead of `icon` while active (empty = same icon)
    property bool active: false                     // e.g. liked / repeat on
    property int size: 44
    property int iconSize: 20
    property int cornerRadius: 10
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color baseColor: "#33000000"
    property color hoverColor: "#55000000"
    property color iconColor: "black"
    property color activeColor: "white"             // icon color while active

    implicitWidth: size
    implicitHeight: size
    padding: 0
    Accessible.name: text                           // text is the tooltip-style label, not drawn

    contentItem: Text {
        text: btn.active && btn.activeIcon !== "" ? btn.activeIcon : btn.icon
        color: btn.active ? btn.activeColor : btn.iconColor
        font.family: btn.fontFamily
        font.pixelSize: btn.iconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: btn.cornerRadius
        color: btn.hovered ? btn.hoverColor : btn.baseColor
    }
}
