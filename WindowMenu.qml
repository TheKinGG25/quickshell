import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: windowMenu
    property var root
    property int selectedDesktop: root ? root.currentDesktop : 1

    anchors { top: true; left: true; right: true }
    margins.top: 0
    property int windowWidth: 500
    margins.left: (screen.width - windowWidth) / 2
    margins.right: (screen.width - windowWidth) / 2

    implicitWidth: windowWidth
    implicitHeight: 500

    color: "transparent"
    visible: root && root.activeWindowScreen === screen

    onVisibleChanged: {
        if (visible && root) {
            selectedDesktop = root.currentDesktop;
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-windowmenu"
    WlrLayershell.exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: root.activeWindowScreen = null

        Rectangle {
            width: parent.width - 40
            height: Math.min(column.implicitHeight + 40, 400)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 30

            radius: 16
            color: "#DD11111b"
            border.color: "#313244"
            border.width: 1

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // Desktop Selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: 4
                        delegate: Button {
                            id: desktopBtn
                            property int desktopNum: index + 1
                            text: desktopNum
                            Layout.fillWidth: true
                            flat: true
                            onClicked: windowMenu.selectedDesktop = desktopNum
                            
                            contentItem: Text {
                                text: desktopBtn.text
                                color: windowMenu.selectedDesktop === desktopBtn.desktopNum ? "#89b4fa" : "#cdd6f4"
                                font.bold: windowMenu.selectedDesktop === desktopBtn.desktopNum
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: root.fontFamily
                                font.pixelSize: 16
                            }
                            background: Rectangle {
                                color: desktopBtn.hovered ? "#313244" : "transparent"
                                radius: 8
                                border.color: windowMenu.selectedDesktop === desktopBtn.desktopNum ? "#89b4fa" : "transparent"
                                border.width: 1
                            }
                        }
                    }
                }

                // Window List
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ListView {
                        id: windowListView
                        model: {
                            if (!root) return [];
                            return root.windows.filter(w => w.desktop === windowMenu.selectedDesktop);
                        }
                        spacing: 5
                        delegate: ItemDelegate {
                            id: windowDelegate
                            width: windowListView.width - 20
                            height: 48
                            onClicked: {
                                runProcess.command = ["python3", "/home/thekingg/.config/quickshell/scripts/kwin-windows.py", modelData.id]
                                runProcess.running = true
                                root.activeWindowScreen = null
                            }
                            
                            contentItem: RowLayout {
                                spacing: 12
                                
                                Image {
                                    source: "image://icon/" + modelData.icon
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                
                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: modelData.app
                                        color: "#cdd6f4"
                                        font.bold: true
                                        font.family: root.fontFamily
                                        font.pixelSize: 14
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.title
                                        color: "#a6adc8"
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        visible: modelData.title !== modelData.app
                                    }
                                }
                            }
                            background: Rectangle {
                                color: windowDelegate.hovered ? "#313244" : "transparent"
                                radius: 8
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            visible: windowListView.count === 0
                            text: "No windows on this desktop"
                            color: "#6c7086"
                            font.family: root.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
    
    Process { id: runProcess }
}
