import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
	id: root
    // ── Global constants ──
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 16
    property bool volumeSliderVisible: false

    // ── Shared state ──
    property int currentDesktop: 1
    property int volumeLevel: 50
    property bool volumeMuted: false
    property bool headphonesActive: false
    property int batteryLevel: 80
    property string batteryStatus: "Discharging"
    property var appVolumes: []

    // ── Processes ──
    Process {
        id: appVolumesProcess
        command: ["python3", "/home/thekingg/.config/quickshell/scripts/app-volumes.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    appVolumes = JSON.parse(data)
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
            appVolumesProcess.running = true
        }
    }

    Component.onCompleted: {
        desktopProcess.running = true
        volumeProcess.running = true
        sinkProcess.running = true
        batteryLevelProcess.running = true
        batteryStatusProcess.running = true
    }

    Bar { root: root }
    VolumeSlider { root: root }
}
