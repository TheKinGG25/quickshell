// EditDialogWindow.qml - dialog to change an app's icon and display name, or hide it.
// Opened from WindowMenu (hover a window + F2). Saves into scripts/icons.json via
// scripts/save-icons-config.py; "Blacklist" uses scripts/add-to-blacklist.py.
// Entries are keyed by the window's resourceClass.

import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

Window {
    id: editDialogWindow
    property var root
    property var editingApp
    property var originalMapKey
    property var selectedIconPath: ""
    property bool dialogOpen: false
    property var screenRef
    property var parentWindow

    // ── Tweakables ──
    property string dialogTitle: "Edit App Icon & Name"
    property string fallbackFont: "JetBrainsMono Nerd Font"     // used if root is not set yet
    property string uiFont: root ? root.fontFamily : fallbackFont
    property int refreshDelayMs: 500                            // wait before re-reading the window list after saving
    property color textColor: "#cdd6f4"
    property color labelColor: "#a6adc8"                        // "Icon:", "Display Name:"
    property color placeholderColor: "#6c7086"
    property color accentColor: "#89b4fa"                       // "Selected: ..." line
    property color fieldColor: "#313244"                        // path input background
    property color fieldBorder: "#45475a"
    property color nameFieldColor: "#1e1e2e"                    // display name input background
    property color buttonColor: "#313244"
    property color buttonHover: "#45475a"
    property color dangerText: "#f38ba8"                        // "Blacklist" text
    property color dangerColor: "#45283c"
    property color dangerHover: "#6b3a4d"

    visible: dialogOpen
    width: 450
    height: 450
    x: (screenRef ? (screenRef.width - width) / 2 : 0)
    y: (screenRef ? Math.max(20, (screenRef.height - height) / 2) : 0)

    Process { id: saveConfigProcess }

    Process { id: blacklistProcess }

    // "Select Icon" file picker
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
        interval: editDialogWindow.refreshDelayMs
        running: false
        onTriggered: {
            if (root && root.windowsProcess) {
                root.windowsProcess.running = true
            }
        }
    }

    PopupCard {
        root: editDialogWindow.root
        anchors.fill: parent
        color: root ? root.colBlack : "#11111b"     // solid, unlike the see-through popups

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Text {
                text: editDialogWindow.dialogTitle
                color: editDialogWindow.textColor
                font.bold: true
                font.family: editDialogWindow.uiFont
                font.pixelSize: 16
                Layout.fillWidth: true
            }

            // ── Icon: file picker or pasted path / icon name ──
            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true

                Text {
                    text: "Icon:"
                    color: editDialogWindow.labelColor
                    font.family: editDialogWindow.uiFont
                    font.pixelSize: 12
                }

                DialogButton {
                    text: selectedIconPath ? "Change Icon" : "Select Icon"
                    Layout.fillWidth: true
                    onClicked: iconFileDialog.open()
                    fontFamily: editDialogWindow.uiFont
                    textColor: editDialogWindow.textColor
                    baseColor: editDialogWindow.buttonColor
                    hoverColor: editDialogWindow.buttonHover
                }

                Text {
                    text: "Or paste path:"
                    color: editDialogWindow.labelColor
                    font.family: editDialogWindow.uiFont
                    font.pixelSize: 11
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: editDialogWindow.fieldColor
                    radius: 4
                    border.color: editDialogWindow.fieldBorder
                    border.width: 1

                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 8
                        color: editDialogWindow.textColor
                        font.family: editDialogWindow.uiFont
                        font.pixelSize: 12
                        text: selectedIconPath
                        onTextChanged: selectedIconPath = text
                        selectByMouse: true

                        // Placeholder
                        Text {
                            visible: !parent.text
                            text: "/path/to/icon.png"
                            color: editDialogWindow.placeholderColor
                            font.family: parent.font.family
                            font.pixelSize: parent.font.pixelSize
                            anchors.margins: 8
                        }
                    }
                }

                Text {
                    visible: selectedIconPath.length > 0
                    text: "Selected: " + selectedIconPath
                    color: editDialogWindow.accentColor
                    font.family: editDialogWindow.uiFont
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideLeft
                }
            }

            // ── Display name ──
            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true

                Text {
                    text: "Display Name:"
                    color: editDialogWindow.labelColor
                    font.family: editDialogWindow.uiFont
                    font.pixelSize: 12
                }

                TextField {
                    id: editAppInput
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: editDialogWindow.nameFieldColor
                        border.color: editDialogWindow.fieldColor
                        border.width: 1
                        radius: 4
                    }
                    color: editDialogWindow.textColor
                    font.family: editDialogWindow.uiFont
                    Keys.onReturnPressed: saveDialog()
                }
            }

            Item { Layout.fillHeight: true }

            // ── Save | Cancel | Blacklist ──
            RowLayout {
                spacing: 10
                Layout.fillWidth: true

                DialogButton {
                    text: "Save"
                    Layout.fillWidth: true
                    onClicked: saveDialog()
                    fontFamily: editDialogWindow.uiFont
                    textColor: editDialogWindow.textColor
                    baseColor: editDialogWindow.buttonColor
                    hoverColor: editDialogWindow.buttonHover
                }

                DialogButton {
                    text: "Cancel"
                    Layout.fillWidth: true
                    onClicked: closeDialog()
                    fontFamily: editDialogWindow.uiFont
                    textColor: editDialogWindow.textColor
                    baseColor: editDialogWindow.buttonColor
                    hoverColor: editDialogWindow.buttonHover
                }

                DialogButton {
                    text: "Blacklist"
                    Layout.fillWidth: true
                    onClicked: blacklistApp()
                    fontFamily: editDialogWindow.uiFont
                    textColor: editDialogWindow.dangerText
                    baseColor: editDialogWindow.dangerColor
                    hoverColor: editDialogWindow.dangerHover
                }
            }
        }
    }

    // Called by WindowMenu on F2 with the hovered window's data
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
