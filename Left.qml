import QtQuick

Row {
    property var root
    spacing: 20

    Repeater {
        model: 4
        delegate: Text {
            text: index + 1
            color: (index + 1) === root.currentDesktop ? "#ffffff" : "#666666"
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            font.bold: (index + 1) === root.currentDesktop
        }
    }
}
