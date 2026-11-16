// lockscreen/LockSurface.qml - the look shared by the lock screen and the login screen.
//
// Used by LockScreen.qml (lock, inside the bar) and greeter.qml (greetd login screen), so
// both look the same: change it here and both follow. The login screen runs from a copy in
// /etc/greetd/quickshell, so after a change run greeter/install.sh again.
//
// It only draws and collects keys. The caller owns the password text (shared by every monitor),
// checks it, and sets `busy` / `errorText`. Keys typed here arrive through `typed` / `erased` /
// `cleared` / `submitted`. Anything put inside a LockSurface (e.g. the greeter's session picker)
// sits at the bottom of the screen.

import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: surface

    // ── Inputs from the caller ──
    property url wallpaper                // image behind everything
    property string userName: ""          // shown above the password box
    property int passwordLength: 0        // number of dots to draw
    property bool busy: false             // checking the password
    property string errorText: ""         // e.g. "Wrong password", empty = none

    signal typed(string text)
    signal erased()
    signal cleared()
    signal submitted()

    default property alias footer: footerSlot.data

    // ── Tweakables ──
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSubtext: "#a6adc8"
    property color colAccent: "#89b4fa"
    property color colError: "#f38ba8"
    property color fieldBg: "#99181825"     // password box (99 = ~60% opacity)
    property color fieldBorder: "#45475a"
    property real wallpaperBlur: 1.0        // 0..1 of blurMax
    property int wallpaperBlurMax: 64       // blur radius in px
    property real wallpaperDim: -0.35       // brightness, negative = darker
    property int clockSize: 120
    property int dateSize: 22
    property int nameSize: 20
    property int fieldWidth: 320
    property int fieldHeight: 48
    property int dotSize: 10
    property string timeFormat: "HH:mm"
    property string dateFormat: "dddd d MMMM"

    focus: true

    Rectangle { anchors.fill: parent; color: "#11111b" }   // shown until the wallpaper has loaded

    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: surface.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false                      // only the effect below draws it
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaperImage
        visible: wallpaperImage.status === Image.Ready
        blurEnabled: true
        blur: surface.wallpaperBlur
        blurMax: surface.wallpaperBlurMax
        brightness: surface.wallpaperDim
        autoPaddingEnabled: false           // keeps the blurred edges from fading to transparent
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -surface.height * 0.08
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, surface.timeFormat)
            color: surface.colText
            font { family: surface.fontFamily; pixelSize: surface.clockSize; bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, surface.dateFormat)
            color: surface.colSubtext
            font { family: surface.fontFamily; pixelSize: surface.dateSize }
        }

        Item { width: 1; height: surface.clockSize * 0.6 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: surface.userName
            color: surface.colText
            font { family: surface.fontFamily; pixelSize: surface.nameSize }
        }

        Item { width: 1; height: 6 }

        // Password box: dots only, the text itself never reaches this file
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: surface.fieldWidth
            height: surface.fieldHeight
            radius: height / 2
            color: surface.fieldBg
            border.width: 2
            border.color: surface.errorText ? surface.colError
                        : surface.busy ? surface.colAccent
                        : surface.fieldBorder
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors.centerIn: parent
                spacing: surface.dotSize * 0.6
                Repeater {
                    model: Math.min(surface.passwordLength, Math.floor((surface.fieldWidth - 40) / (surface.dotSize * 1.6)))
                    Rectangle {
                        width: surface.dotSize; height: width; radius: width / 2
                        color: surface.busy ? surface.colAccent : surface.colText
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: surface.passwordLength === 0
                text: surface.busy ? "Checking..." : "Password"
                color: surface.colSubtext
                opacity: 0.6
                font { family: surface.fontFamily; pixelSize: 15 }
            }

            // Shake on a wrong password
            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -8; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 22
            text: surface.errorText
            color: surface.colError
            font { family: surface.fontFamily; pixelSize: 14 }
        }
    }

    onErrorTextChanged: if (errorText) shake.restart()

    Item {
        id: footerSlot
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 40 }
        width: childrenRect.width
        height: childrenRect.height
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) surface.submitted()
        else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier) surface.cleared()
            else surface.erased()
        }
        else if (event.key === Qt.Key_Escape) surface.cleared()
        else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) surface.typed(event.text)
        else return
        event.accepted = true
    }
}
