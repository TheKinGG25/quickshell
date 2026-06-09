import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: shellRoot
    // ── Global constants ──
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 16
    property var activeVolumeScreen: null
    property var activePowerScreen: null
    property var activePowerProfileScreen: null

    // ── Shared state ──
    property int currentDesktop: 1
    property int volumeLevel: 50
    property bool volumeMuted: false
    property bool headphonesActive: false
    property int batteryLevel: 80
    property string batteryStatus: "Discharging"
    property string powerProfile: "balanced"
    property var appVolumes: []
    property var windows: []
    property var activeWindowScreen: null
    onActiveWindowScreenChanged: {
        if (activeWindowScreen) windowsProcess.running = true
    }

    // ── Processes ──
    Timer {
        id: windowsUpdateTimer
        interval: 500  // Update every 500ms
        running: root.activeWindowScreen !== null
        repeat: true
        onTriggered: {
            windowsProcess.running = true
        }
    }
    
    Process {
        id: windowsProcess
        command: ["python3", "/home/thekingg/.config/quickshell/scripts/kwin-windows.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var newWins = JSON.parse(data);
                    // Filter out desktop selectors (id starts with 8_) and windows with empty titles
                    newWins = newWins.filter(w => !w.id.startsWith("8_") && w.title.length > 0);
                    
                    // Remove duplicates based on ID
                    var uniqueWins = [];
                    var seenIds = {};
                    for (var i = 0; i < newWins.length; i++) {
                        if (!seenIds[newWins[i].id]) {
                            uniqueWins.push(newWins[i]);
                            seenIds[newWins[i].id] = true;
                        }
                    }

                    if (JSON.stringify(uniqueWins) !== JSON.stringify(windows)) {
                        windows = uniqueWins;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: appVolumesProcess
        command: ["python3", "/home/thekingg/.config/quickshell/scripts/app-volumes.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var newVols = JSON.parse(data);
                    if (JSON.stringify(newVols) !== JSON.stringify(appVolumes)) {
                        appVolumes = newVols;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: desktopProcess
        command: ["python3", "/home/thekingg/.config/quickshell/scripts/kwin-desktop.py"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                if (!isNaN(n)) currentDesktop = n
            }
        }
    }

    Process {
        id: volumeProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(/\s+/)
                if (parts.length >= 2)
                    volumeLevel = Math.round(parseFloat(parts[1]) * 100)
                volumeMuted = data.includes("MUTED")
            }
        }
    }

    Process {
        id: sinkProcess
        command: ["bash", "-c", "wpctl inspect @DEFAULT_AUDIO_SINK@ | grep -c api.bluez5.address || true"]
        stdout: SplitParser {
            onRead: data => { headphonesActive = parseInt(data.trim()) > 0 }
        }
    }

    Process {
        id: batteryLevelProcess
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                if (!isNaN(n)) batteryLevel = n
            }
        }
    }

    Process {
        id: batteryStatusProcess
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: SplitParser {
            onRead: data => { batteryStatus = data.trim() }
        }
    }

    Process {
        id: powerProfileProcess
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim()
                if (p.length > 0) powerProfile = p
            }
        }
    }

    // ── Timers ──
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            desktopProcess.running = false
            desktopProcess.running = true
        }
    }

    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            volumeProcess.running = true
            sinkProcess.running = true
            batteryLevelProcess.running = true
            batteryStatusProcess.running = true
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            // Only poll app volumes every second to prevent UI stutter
            if (!shellRoot.activeVolumeScreen)
                appVolumesProcess.running = true

            if (shellRoot.activeWindowScreen)
                windowsProcess.running = true

            powerProfileProcess.running = true
        }
    }

    Component.onCompleted: {
        desktopProcess.running = true
        volumeProcess.running = true
        sinkProcess.running = true
        batteryLevelProcess.running = true
        batteryStatusProcess.running = true
        appVolumesProcess.running = true
        windowsProcess.running = true
        powerProfileProcess.running = true
    }

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        VolumeSlider {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        PowerMenu {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        WindowMenu {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        PowerProfileMenu {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }
}
