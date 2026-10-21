// Clipboard.qml - clipboard history picker (WORK IN PROGRESS, not working yet).
// Meant to list recent copies, highlight root.clipboardIndex (moved by scripts/clipboard.py)
// and paste the chosen one. Right now: 3 placeholder rows and nothing opens it.
// What is missing is listed in .claude/TODO.md.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: clipboardWindow
    property var root
    property bool clipboardOpen: false      // nothing sets this yet

    // ── Tweakables ──
    property int widthWindow: 400           // card width
    property int itemCount: 3               // placeholder rows
    property int topOffset: 50              // distance from the screen top
    property int rightOffset: 120           // distance from the right screen edge

    visible: clipboardOpen
    anchors { top: true; right: true }
    margins { top: topOffset; right: rightOffset }
    width: widthWindow
    height: contentCol.implicitHeight + 20
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-clipboard"
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        // Visible card
        Rectangle {
            width: widthWindow
            height: contentCol.implicitHeight + 20
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 0
            anchors.rightMargin: 0

            radius: 8
            color: "#DD11111b"
            border.color: "#313244"
            border.width: 1

            ColumnLayout {
                id: contentCol
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: itemCount
                    CopiedItem {
                        // label: "Copied Item " + (index + 1)
                        label: index === root.clipboardIndex ? "Focused Item " + (index + 1) : "Copied Item " + (index + 1)
                        isFocused: index === focusedIndex || index === root.clipboardIndex     // focusedIndex is undefined (see TODO)
                    }
                }
            }
        }
    }

    // One clipboard row
    component CopiedItem: Button {
        id: cpControl
        property string label: ""
        property bool isFocused: false
        Layout.fillWidth: true
        width: widthWindow - 20
        padding: 8

        contentItem: RowLayout {
            spacing: 10
            Text {
                font.family: root.fontFamily
                font.pixelSize: fontSize        // undefined here (see TODO)
                color: "white"
                Layout.maximumWidth: widthWindow - 40
                wrapMode: Text.WrapAnywhere
                text: cpControl.label

            }
        }

        // Highlighted when hovered or selected with the keyboard
        background: Rectangle {
            implicitWidth: widthWindow - 20
            implicitHeight: 35
            radius: 4
            color: cpControl.hovered || cpControl.isFocused ? "#313244" : "transparent"
        }
    }
}
