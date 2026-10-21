import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
	id: clipboardWindow
	property var root
	property bool clipboardOpen: false
	property int widthWindow: 400

	visible: clipboardOpen
	anchors { top: true; right: true }
	margins { top: 50; right: 120 }
	width: widthWindow
	height: contentCol.implicitHeight + 20
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-clipboard"
	color: "transparent"

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true

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
					model: 3
					CopiedItem {
						// label: "Copied Item " + (index + 1)
						label: index === root.clipboardIndex ? "Focused Item " + (index + 1) : "Copied Item " + (index + 1) 
						isFocused: index === focusedIndex || index === root.clipboardIndex
					}
				}
			}
		}
	}

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
				font.pixelSize: fontSize
				color: "white"
				Layout.maximumWidth: widthWindow - 40
		        wrapMode: Text.WrapAnywhere
				text: cpControl.label
				
			}
		}

		background: Rectangle {
			implicitWidth: widthWindow - 20
			implicitHeight: 35
			radius: 4
			color: cpControl.hovered || cpControl.isFocused ? "#313244" : "transparent"
		}
	}	
}
