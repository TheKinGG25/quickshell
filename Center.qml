// Center.qml - clock in the middle of the bar.
// A small ring fills up over each 12h half of the day (AM / PM color), then the time and date.
// Left click: WindowMenu (KWin only, see the handler). Middle click: PowerMenu.

import QtQuick
import QtQuick.Layouts

MouseArea {
    id: centerArea
    property var root
    property var screen

    // ── Tweakables ──
    property string timeFormat: "hh:mm:ss AP"       // Qt.formatTime syntax, e.g. "HH:mm" for 24h
    property string dateFormat: "dddd - dd/MM/yy"   // Qt.formatDate syntax
    property string separator: " | "                // between time and date
    property color clockColor: "white"
    property int clockFontSize: 14
    property int arcSize: 22                        // ring canvas size (px)
    property int arcRadius: 8
    property real arcWidth: 2.5
    property string arcTrackColor: "rgba(255,255,255,0.15)" // empty part of the ring
    property string amColor: root.colBlue           // ring color before noon
    property string pmColor: root.colPeach          // ring color after noon

    implicitWidth: contentRow.implicitWidth + 20
    Layout.fillHeight: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: (mouse) => {
        if (mouse.button === Qt.MiddleButton) {
            root.activePowerScreen = (root.activePowerScreen === screen ? null : screen)
        } else if (mouse.button === Qt.LeftButton && !root.hyprland) {
            // WindowMenu groups windows by desktop number, which the Hyprland grid ids are not
            root.activeWindowScreen = (root.activeWindowScreen === screen ? null : screen)
        }
    }

    function clockString() {
        var now = new Date()
        return Qt.formatTime(now, timeFormat) + separator + Qt.formatDate(now, dateFormat)
    }

    Row {
        id: contentRow
        spacing: 8
        anchors.centerIn: parent

    // Ring: progress through the current 12h half of the day, repainted every minute
    Canvas {
        id: clockArc
        width: centerArea.arcSize; height: centerArea.arcSize
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
            var cx = width / 2, cy = height / 2, r = centerArea.arcRadius

            // full ring (track)
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = centerArea.arcTrackColor
            ctx.lineWidth = centerArea.arcWidth
            ctx.stroke()

            // filled part, starting at 12 o'clock
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2,
                    -Math.PI / 2 + progress * Math.PI * 2)
            ctx.strokeStyle = isPM ? centerArea.pmColor : centerArea.amColor
            ctx.lineWidth = centerArea.arcWidth
            ctx.lineCap = "round"
            ctx.stroke()
        }

        Component.onCompleted: requestPaint()
    }

    // Time + date text, updated every second
    Text {
        id: clockText
        anchors.verticalCenter: parent.verticalCenter
        color: centerArea.clockColor
        font.pixelSize: centerArea.clockFontSize
        font.family: root.fontFamily

        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: clockText.text = centerArea.clockString()
        }

        Component.onCompleted: text = centerArea.clockString()
    }
}
}
