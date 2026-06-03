import QtQuick

Row {
    spacing: 8

    Canvas {
        id: clockArc
        width: 22; height: 22
        anchors.verticalCenter: parent.verticalCenter

        property bool isPM: new Date().getHours() >= 12
        property real progress: {
            var now = new Date()
            return (now.getHours() % 12 + now.getMinutes() / 60) / 12
        }

        Timer {
            interval: 60000; running: true; repeat: true
            onTriggered: {
                var now = new Date()
                clockArc.isPM = now.getHours() >= 12
                clockArc.progress = (now.getHours() % 12 + now.getMinutes() / 60) / 12
                clockArc.requestPaint()
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2, r = 8

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = "rgba(255,255,255,0.15)"
            ctx.lineWidth = 2.5
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2,
                    -Math.PI / 2 + progress * Math.PI * 2)
            ctx.strokeStyle = isPM ? "#fab387" : "#89b4fa"
            ctx.lineWidth = 2.5
            ctx.lineCap = "round"
            ctx.stroke()
        }

        Component.onCompleted: requestPaint()
    }

    Text {
        id: clockText
        anchors.verticalCenter: parent.verticalCenter
        color: "white"
        font.pixelSize: 14
        font.family: "JetBrainsMono Nerd Font"

        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: clockText.text =
                Qt.formatTime(new Date(), "hh:mm:ss AP") + " | " +
                Qt.formatDate(new Date(), "dddd - dd/MM/yy")
        }

        Component.onCompleted: text =
            Qt.formatTime(new Date(), "hh:mm:ss AP") + " | " +
            Qt.formatDate(new Date(), "dddd - dd/MM/yy")
    }
}
