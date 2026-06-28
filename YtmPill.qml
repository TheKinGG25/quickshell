import QtQuick

Rectangle {
    property var root
    property var screen

    visible: root.ytmAvailable
    width: 280
    height: 22
    radius: 6
    clip: true
    color: "#ff4444"

    Rectangle {
        id: artThumb
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.top: parent.top
        anchors.topMargin: (parent.height - height) / 2
        width: 16
        height: 16
        radius: 2
        clip: true
        color: "#333333"

        Image {
            anchors.fill: parent
            source: root.ytmArt
            fillMode: Image.PreserveAspectCrop
        }
    }

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
            color: "black"
            font.pixelSize: 15
            font.family: root.fontFamily
            font.bold: true
        }

        Text {
            id: artistText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.6)
            text: root.ytmArtist
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            color: "#1a0000"
            font.pixelSize: 12
            font.family: root.fontFamily
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: Qt.rgba(0, 0, 0, 0.3)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: parent.width * (root.ytmProgress / 100)
        height: 2
        color: Qt.rgba(0, 0, 0, 0.7)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.activeYtmScreen = (root.activeYtmScreen === screen ? null : screen)
        }
    }
}
