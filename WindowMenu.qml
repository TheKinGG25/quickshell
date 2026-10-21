// WindowMenu.qml - open-window switcher, centered under the bar. Opened by left-clicking the clock.
// Top: one tab per desktop (count: root.desktopCount). Below: windows on the selected desktop.
// Click a window to focus it. Hover a window + F2 to edit its icon / name (EditDialogWindow.qml).
// Window list comes from root.windows (scripts/kwin-windows.py + scripts/icons.json).

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

    // ── Tweakables ──
    property int windowWidth: 500       // popup width (the card is 40px narrower)
    property int maxCardHeight: 400     // list scrolls beyond this
    property int topOffset: 30          // distance from the screen top (just below the bar)
    property int cardRadius: 16
    property int rowHeight: 48          // one window row
    property int iconSize: 24           // app icon in each row
    property int closeDelayMs: 200      // wait after the mouse leaves before closing
    property string emptyText: "No windows on this desktop"

    anchors { top: true; left: true; right: true }
    margins.top: 0
    margins.left: (screen.width - windowWidth) / 2
    margins.right: (screen.width - windowWidth) / 2

    implicitWidth: windowWidth
    implicitHeight: 500

    color: "transparent"
    visible: root && (root.activeWindowScreen === screen)

    // Always open on the desktop you are currently on
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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand     // needed for F2
    WlrLayershell.namespace: "quickshell-windowmenu"
    WlrLayershell.exclusiveZone: -1

    // Close shortly after the mouse leaves (not while the edit dialog is open)
    Timer {
        id: closeMenuTimer
        interval: windowMenu.closeDelayMs
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

        // Visible card
        Rectangle {
            width: parent.width - 40
            height: Math.min(column.implicitHeight + 40, windowMenu.maxCardHeight)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: windowMenu.topOffset

            radius: windowMenu.cardRadius
            color: root.popupBg
            border.color: root.popupBorder
            border.width: 1

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                // ── Desktop tabs ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: root.desktopCount
                        delegate: Button {
                            id: desktopBtn
                            property int desktopNum: index + 1
                            text: desktopNum
                            Layout.fillWidth: true
                            flat: true
                            onClicked: windowMenu.selectedDesktop = desktopNum

                            contentItem: Text {
                                text: desktopBtn.text
                                color: windowMenu.selectedDesktop === desktopBtn.desktopNum ? root.colBlue : root.colText
                                font.bold: windowMenu.selectedDesktop === desktopBtn.desktopNum
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: root.fontFamily
                                font.pixelSize: 16
                            }
                            background: Rectangle {
                                color: desktopBtn.hovered ? root.colSurface : "transparent"
                                radius: 8
                                border.color: windowMenu.selectedDesktop === desktopBtn.desktopNum ? root.colBlue : "transparent"
                                border.width: 1
                            }
                        }
                    }
                }

                // ── Window list ──
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

                        // One row: icon + app name
                        delegate: ItemDelegate {
                            id: windowDelegate
                            width: windowListView.width - 20
                            height: windowMenu.rowHeight
                            focus: false
                            activeFocusOnTab: false

                            // F2 on the hovered row opens the icon / name editor
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
                                    Layout.preferredWidth: windowMenu.iconSize
                                    Layout.preferredHeight: windowMenu.iconSize
                                    fillMode: Image.PreserveAspectFit
                                    // Not asynchronous: theme icons (image://icon) loaded off the GUI thread
                                    // trigger "Cannot create children for a parent that is in a different thread"
                                    asynchronous: false
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
                                    color: root.colText
                                    font.bold: true
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                            // Selected row: surface color, hovered row: darker
                            background: Rectangle {
                                color: windowListView.currentIndex === index ? root.colSurface : (windowDelegate.hovered ? root.colDark : "transparent")
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
                                // Click: focus that window (scripts/kwin-windows.py <id>) and close
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
                            text: windowMenu.emptyText
                            color: root.colMuted
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
