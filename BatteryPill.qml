import QtQuick

Rectangle {
    property var root
    property var screen

    property color pillColor: root.batteryLevel > 80 ? "#2ecc71" :
                              root.batteryLevel > 60 ? "#a8d832" :
                              root.batteryLevel > 40 ? "#f1c40f" :
                              root.batteryLevel > 20 ? "#e67e22" : "#e74c3c"

    property string icon: root.batteryStatus === "Charging"     ? "↑" :
                          root.batteryStatus === "Not charging" ? "—" : "↓"

    width: Math.max(number.implicitWidth + icon_class.implicitWidth + 10, 55)
    height: 22
    radius: 6
    color: pillColor

    Text {
        id:number
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.batteryLevel
        color: "black"
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    Text {
        id:icon_class
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: icon
        color: "black"
        font.pixelSize: root.fontSize
        font.family: root.fontFamily
        font.bold: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.activePowerProfileScreen = (root.activePowerProfileScreen === screen ? null : screen)
        }
    }
}
