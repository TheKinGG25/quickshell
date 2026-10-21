import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Window {
    id: editDialogWindow
    property var root
    property var editingApp
    property var originalMapKey
    property var selectedIconPath: ""
    property bool dialogOpen: false
    property var screenRef
    property var parentWindow
    
    visible: dialogOpen
    width: 450
    height: 450
    x: (screenRef ? (screenRef.width - width) / 2 : 0)
    y: (screenRef ? Math.max(20, (screenRef.height - height) / 2) : 0)
    
    Process { id: saveConfigProcess }
    
    Process { id: blacklistProcess }
    
    FileDialog {
        id: iconFileDialog
        title: "Select Icon File"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg *.ico)", "All files (*)"]
        onAccepted: {
            var filePath = selectedFile.toString()
            // Remove file:// prefix if present
            if (filePath.startsWith("file://")) {
                filePath = filePath.substring(7)
            }
            selectedIconPath = filePath
        }
    }
    
    Timer {
        id: refreshTimer
        interval: 500
        running: false
        onTriggered: {
            if (root && root.windowsProcess) {
                root.windowsProcess.running = true
            }
        }
    }
    
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
                
                Button {
                    text: selectedIconPath ? "Change Icon" : "Select Icon"
                    Layout.fillWidth: true
                    onClicked: iconFileDialog.open()
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
                
                Text {
                    text: "Or paste path:"
                    color: "#a6adc8"
                    font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: "#313244"
                    radius: 4
                    border.color: "#45475a"
                    border.width: 1
                    
                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 8
                        color: "#cdd6f4"
                        font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        text: selectedIconPath
                        onTextChanged: selectedIconPath = text
                        selectByMouse: true
                        
                        Text {
                            visible: !parent.text
                            text: "/path/to/icon.png"
                            color: "#6c7086"
                            font.family: parent.font.family
                            font.pixelSize: parent.font.pixelSize
                            anchors.margins: 8
                        }
                    }
                }
                
                Text {
                    visible: selectedIconPath.length > 0
                    text: "Selected: " + selectedIconPath
                    color: "#89b4fa"
                    font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideLeft
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
                    Keys.onReturnPressed: saveDialog()
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                
                Button {
                    text: "Save"
                    Layout.fillWidth: true
                    onClicked: saveDialog()
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
                    onClicked: closeDialog()
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
                    text: "Blacklist"
                    Layout.fillWidth: true
                    onClicked: blacklistApp()
                    contentItem: Text {
                        text: parent.text
                        color: "#f38ba8"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: root ? root.fontFamily : "JetBrainsMono Nerd Font"
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#6b3a4d" : "#45283c"
                        radius: 4
                    }
                }
            }
        }
    }
    
    function setEditingApp(app) {
        editingApp = app
        // Store the original key based on resourceClass or id (not the display name which can change)
        originalMapKey = app.resourceClass || app.id || app.app
        selectedIconPath = app.icon || ""
        editAppInput.text = app.app || ""
        dialogOpen = true
        editAppInput.forceActiveFocus()
    }
    
    function saveDialog() {
        if (editingApp) {
            var mapKey = originalMapKey
            var iconValue = selectedIconPath
            var displayNameValue = editAppInput.text
            
            // Log for debugging
            console.log("Saving: mapKey=" + mapKey + ", icon=" + iconValue + ", displayName=" + displayNameValue)
            
            saveConfigProcess.command = ["python3", root.scriptsDir + "/save-icons-config.py", mapKey, iconValue, displayNameValue]
            saveConfigProcess.running = true
            
            // Refresh windows after a short delay to allow the save to complete
            refreshTimer.restart()
            closeDialog()
        }
    }
    
    function closeDialog() {
        dialogOpen = false
        editingApp = null
        selectedIconPath = ""
    }
    
    function blacklistApp() {
        if (editingApp) {
            var mapKey = originalMapKey
            console.log("Blacklisting: " + mapKey)
            
            blacklistProcess.command = ["python3", root.scriptsDir + "/add-to-blacklist.py", mapKey]
            blacklistProcess.running = true
            
            // Refresh windows after a short delay
            refreshTimer.restart()
            closeDialog()
        }
    }
    
    onDialogOpenChanged: {
        if (!dialogOpen && parentWindow) {
            parentWindow.shouldShowMenu = false
        }
    }
}
