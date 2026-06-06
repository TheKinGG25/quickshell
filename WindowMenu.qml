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
    property var editingApp: null
    property bool editDialogOpen: false
    property bool shouldShowMenu: false

    anchors { top: true; left: true; right: true }
    margins.top: 0
    property int windowWidth: 500
    margins.left: (screen.width - windowWidth) / 2
    margins.right: (screen.width - windowWidth) / 2

    implicitWidth: windowWidth
    implicitHeight: 500

    color: "transparent"
    visible: shouldShowMenu && !editDialogOpen

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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onExited: {
            if (!windowMenu.editDialogOpen) {
                windowMenu.shouldShowMenu = false
            }
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
                        focus: false
                        currentIndex: -1
                        
                        delegate: ItemDelegate {
                            id: windowDelegate
                            width: windowListView.width - 20
                            height: 48
                            
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
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onEntered: {
                                    windowListView.currentIndex = index
                                    windowListView.focus = true
                                }
                                onExited: {
                                    windowListView.focus = false
                                }
                                onClicked: (mouse) => {
                                    windowListView.currentIndex = index;
                                    if (mouse.button === Qt.RightButton) {
                                        windowMenu.editingApp = modelData;
                                        windowMenu.editDialogOpen = true;
                                        editIconInput.text = modelData.icon || "";
                                        editAppInput.text = modelData.app || "";
                                        editIconInput.forceActiveFocus();
                                    } else if (mouse.button === Qt.LeftButton) {
                                        if (modelData && modelData.id) {
                                            runProcess.command = ["python3", "/home/thekingg/.config/quickshell/scripts/kwin-windows.py", modelData.id]
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

    // Separate floating dialog window
    ShellWindow {
    id: editDialogWindow
    visible: windowMenu.editDialogOpen
    width: 450
    height: 450
    x: (screen.width - width) / 2
    y: Math.max(20, (screen.height - height) / 2)
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-editdialog"
    
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#11111b"
        border.color: "#313244"
        border.width: 1
        
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Text {
                text: "Edit App Icon & Name"
                color: "#cdd6f4"
                font.bold: true
                font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                Layout.fillWidth: true
            }
            
            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true
                
                Text {
                    text: "Icon:"
                    color: "#a6adc8"
                    font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
                
                TextField {
                    id: editIconInput
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: "#1e1e2e"
                        border.color: "#313244"
                        border.width: 1
                        radius: 4
                    }
                    color: "#cdd6f4"
                    font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                }
            }
            
            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true
                
                Text {
                    text: "Display Name:"
                    color: "#a6adc8"
                    font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
                
                TextField {
                    id: editAppInput
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: "#1e1e2e"
                        border.color: "#313244"
                        border.width: 1
                        radius: 4
                    }
                    color: "#cdd6f4"
                    font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    Keys.onReturnPressed: {
                        if (windowMenu.editingApp) {
                            var mapKey = windowMenu.editingApp.app || windowMenu.editingApp.resourceClass || windowMenu.editingApp.id;
                            saveConfigProcess.command = ["python3", "/home/thekingg/.config/quickshell/scripts/save-icons-config.py", mapKey, editIconInput.text]
                            saveConfigProcess.running = true
                            windowMenu.editDialogOpen = false
                            windowMenu.editingApp = null
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                
                Button {
                    text: "Save"
                    Layout.fillWidth: true
                    onClicked: {
                        if (windowMenu.editingApp) {
                            var mapKey = windowMenu.editingApp.app || windowMenu.editingApp.resourceClass || windowMenu.editingApp.id;
                            saveConfigProcess.command = ["python3", "/home/thekingg/.config/quickshell/scripts/save-icons-config.py", mapKey, editIconInput.text]
                            saveConfigProcess.running = true
                            windowMenu.editDialogOpen = false
                            windowMenu.editingApp = null
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#cdd6f4"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#45475a" : "#313244"
                        radius: 4
                    }
                }
                
                Button {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: {
                        windowMenu.editDialogOpen = false
                        windowMenu.editingApp = null
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#cdd6f4"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#45475a" : "#313244"
                        radius: 4
                    }
                }
            }
        }
    }
}
}
