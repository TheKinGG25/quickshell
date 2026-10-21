// DialogButton.qml - flat button with a hover color, used in EditDialogWindow.qml.
// Set `text`, `onClicked`, and optionally the colors (e.g. a red "danger" button).

import QtQuick
import QtQuick.Controls

Button {
    id: btn

    property color textColor: "#cdd6f4"
    property color baseColor: "#313244"
    property color hoverColor: "#45475a"
    property string fontFamily: "JetBrainsMono Nerd Font"

    contentItem: Text {
        text: btn.text
        color: btn.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: btn.fontFamily
    }

    background: Rectangle {
        color: btn.hovered ? btn.hoverColor : btn.baseColor
        radius: 4
    }
}
