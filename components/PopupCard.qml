// PopupCard.qml - the dark rounded card every popup draws its content on.
// Colors come from the theme in shell.qml (root.popupBg / root.popupBorder).
// Pass `root: <windowId>.root` (not `root: root`, which would point at this card's own property).

import QtQuick

Rectangle {
    property var root

    radius: 12
    color: root ? root.popupBg : "#DD11111b"
    border.color: root ? root.popupBorder : "#313244"
    border.width: 1
}
