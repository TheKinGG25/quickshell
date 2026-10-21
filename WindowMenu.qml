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
    property bool shouldShowMenu: false

    anchors { top: true; left: true; right: true }
    margins.top: 0
    property int windowWidth: 500
    margins.left: (screen.width - windowWidth) / 2
    margins.right: (screen.width - windowWidth) / 2

    implicitWidth: windowWidth
    implicitHeight: 500

    color: "transparent"
    visible: root && (root.activeWindowScreen === screen)

    onVisibleChanged: {
        if (visible && root) {
            selectedDesktop = root.currentDesktop;
        }
    }

    Connections {
        target: root
        function onActiveWindowScreenChanged() {
            windowMenu.shouldShowMenu = (root.activeWindowScreen === screen)
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-windowmenu"
    WlrLayershell.exclusiveZone: -1

    Timer {
        id: closeMenuTimer
        interval: 200
        running: false
        onTriggered: {
            if (!editDialogWindow.dialogOpen) {
                root.activeWindowScreen = null
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: {
            closeMenuTimer.restart()
        }
        onEntered: {
            closeMenuTimer.stop()
        }

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
                            if (!root || !root.windows) return [];
                            var filtered = root.windows.filter(w => w && w.desktop === windowMenu.selectedDesktop);
                            return filtered;
                        }
                        spacing: 5
                        focus: true
                        currentIndex: -1
                        
                        delegate: ItemDelegate {
                            id: windowDelegate
                            width: windowListView.width - 20
                            height: 48
                            focus: false
                            activeFocusOnTab: false
                            
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_F2) {
                                    editDialogWindow.setEditingApp(modelData);
                                    event.accepted = true;
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: 12
                                
                                Image {
                                    source: {
                                        if (!modelData || !modelData.icon) return "";
                                        var iconName = modelData.icon;
                                        // Try different icon loading strategies
                                        if (iconName.startsWith("org.kde.")) {
                                            return "image://icon/" + iconName.split(".").pop();
                                        }
                                        return "image://icon/" + iconName;
                                    }
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            // Try alternative icon names if first fails
                                            if (modelData && modelData.resourceClass) {
                                                var parts = modelData.resourceClass.split(".");
                                                if (parts.length > 1) {
                                                    source = "image://icon/" + parts[parts.length - 1];
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Text {
                                    text: modelData && modelData.app ? modelData.app : "Unknown App"
                                    color: "#cdd6f4"
                                    font.bold: true
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                            background: Rectangle {
                                color: windowListView.currentIndex === index ? "#313244" : (windowDelegate.hovered ? "#1e1e2e" : "transparent")
                                radius: 8
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                focus: false
                                onEntered: {
                                    windowListView.currentIndex = index
                                    windowDelegate.forceActiveFocus()
                                }
                                onExited: {
                                    windowDelegate.focus = false
                                }
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (modelData && modelData.id) {
                                            runProcess.command = ["python3", root.scriptsDir + "/kwin-windows.py", modelData.id]
                                            runProcess.running = true
                                            root.activeWindowScreen = null
                                        }
                                    }
                                }
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
    Process { id: saveConfigProcess }

    EditDialogWindow {
        id: editDialogWindow
        root: windowMenu.root
        screenRef: windowMenu.screen
        parentWindow: windowMenu
    }
}
