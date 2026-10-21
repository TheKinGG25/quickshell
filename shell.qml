// shell.qml - entry point of the bar (ShellRoot).
//
// Owns ALL shared state and every background poller. Each component gets
// `root: shellRoot` and reads from here, so:
//   - colors / fonts / sizes used in several files -> "Theme" and "Layout" below
//   - how often something refreshes                -> "Polling intervals" below
//   - where scripts live                           -> "Paths" below
//   - what data a pill shows                       -> the Process that fills it ("Processes")

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: shellRoot

    // ── Fonts ──
    property string fontFamily: "JetBrainsMono Nerd Font"   // must be a Nerd Font, icons use its glyphs
    property int fontSize: 16                               // pill text + desktop numbers

    // ── Layout ──
    property int barHeight: 30          // height of the top bar
    property int pillHeight: 22         // height of every pill in Right.qml
    property int pillRadius: 6          // corner radius of the pills
    property int desktopCount: 6        // number of desktops shown in Left.qml and WindowMenu tabs
    property int ytmWidth: 280          // width of YtmPill and of the YtmPanel under it

    // ── Theme (Catppuccin Mocha) ── change a color here and every file follows
    property color popupBg: "#DD11111b"     // popup card background (DD = ~87% opacity)
    property color popupBorder: "#313244"   // popup card border
    property color colSurface: "#313244"    // hovered / selected row, inactive slider track
    property color colSurfaceHover: "#45475a" // hovered button in EditDialog
    property color colDark: "#1e1e2e"       // input field background, light hover
    property color colBlack: "#11111b"      // dialog background
    property color colText: "#cdd6f4"       // main text
    property color colSubtext: "#a6adc8"    // secondary text (labels, app names)
    property color colOverlay: "#7f849c"    // inactive icons
    property color colMuted: "#6c7086"      // placeholder / empty-state text
    property color colBlue: "#89b4fa"
    property color colMauve: "#cba6f7"
    property color colPeach: "#fab387"
    property color colRed: "#f38ba8"
    property color colYellow: "#f9e2af"
    property color colGreen: "#a6e3a1"
    property color colRosewater: "#f5e0dc"  // pressed slider handle

    // ── Paths ──
    property string homeDir: Quickshell.env("HOME")
    property string scriptsDir: homeDir + "/.config/quickshell/scripts"
    property string ytmCacheFile: homeDir + "/.cache/ytmd-now.json"   // written by scripts/ytmd-nowplaying.py

    // ── Polling intervals (ms) ──
    property int desktopPollMs: 200     // current desktop (Left.qml highlight)
    property int windowsPollMs: 500     // window list, only while WindowMenu is open
    property int slowPollMs: 1000       // app volumes, power profile, music
    property int fallbackPollMs: 2000   // battery + volume safety net (volume is normally event driven)
    property int volumeDebounceMs: 30   // groups bursts of pactl events into one read

    // ── Popup visibility ── null = hidden, a screen = shown on that screen
    property var activeVolumeScreen: null
    property var activePowerScreen: null
    property var activePowerProfileScreen: null
    property var activeYtmScreen: null
    property var activeWindowScreen: null
    onActiveWindowScreenChanged: {
        if (activeWindowScreen) windowsProcess.running = true
    }

    // ── Layout helpers written by Bar.qml ──
    property int ytmPillLeftX: 0        // x of the Right section, YtmPanel opens there
    property int rightLength: 0         // unused (see .claude/TODO.md)

    // ── Shared state (filled by the processes below, defaults shown until first read) ──
    property int currentDesktop: 1
    property int volumeLevel: 50
    property bool volumeMuted: false
    property bool headphonesActive: false
    property int batteryLevel: 80
    property string batteryStatus: "Discharging"
    property string powerProfile: "balanced"
    property var appVolumes: []
    property var windows: []
    property bool ytmAvailable: false
    property bool ytmPlaying: false
    property string ytmTitle: ""
    property string ytmArtist: ""
    property string ytmArt: ""
    property int ytmProgress: 0
    property real ytmProgressSeconds: 0
    property real ytmDuration: 0
    property int clipboardIndex: 0
    property bool clipboardRunning: false

    // ── Processes ──

    // Window list refresh while WindowMenu is open. Known bug: `root` is undefined here (see .claude/TODO.md)
    Timer {
        id: windowsUpdateTimer
        interval: windowsPollMs
        running: root.activeWindowScreen !== null
        repeat: true
        onTriggered: {
            windowsProcess.running = true
        }
    }

    // Window list for WindowMenu (scripts/kwin-windows.py prints a JSON array)
    Process {
        id: windowsProcess
        command: ["python3", scriptsDir + "/kwin-windows.py"]
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

    // Per-app volumes for VolumeSlider (scripts/app-volumes.py prints [{id, name, volume}])
    Process {
        id: appVolumesProcess
        command: ["python3", scriptsDir + "/app-volumes.py"]
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

    // Current desktop number for Left.qml (scripts/kwin-desktop.py prints e.g. "3")
    Process {
        id: desktopProcess
        command: ["python3", scriptsDir + "/kwin-desktop.py"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                if (!isNaN(n)) currentDesktop = n
            }
        }
    }

    // Master volume + mute for VolumePill ("Volume: 0.42 [MUTED]")
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

    // Is the default output a bluetooth device? Drives the headphone icon/color in VolumePill
    Process {
        id: sinkProcess
        command: ["bash", "-c", "wpctl inspect @DEFAULT_AUDIO_SINK@ | grep -c api.bluez5.address || true"]
        stdout: SplitParser {
            onRead: data => { headphonesActive = parseInt(data.trim()) > 0 }
        }
    }

    // Pushes a line on every PulseAudio/PipeWire change; restarted by the fallback timer if it dies
    Process {
        id: volumeEventsProcess
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("on sink #") || data.includes("on server"))
                    volumeRefreshTimer.restart()
            }
        }
    }

    // Battery for BatteryPill. First BAT* found: prints capacity, then status
    Process {
        id: batteryProcess
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do cat \"$b/capacity\" \"$b/status\"; exit; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (/^\d+$/.test(line)) batteryLevel = parseInt(line)
                else if (line.length > 0) batteryStatus = line
            }
        }
    }

    // Music for YtmPill / YtmPanel. The JSON file is written by scripts/ytmd-nowplaying.py (start it by hand)
    Process {
        id: ytmProcess
        command: ["cat", ytmCacheFile]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var d = JSON.parse(data)
                    ytmAvailable = d.available === true && !!d.title
                    ytmPlaying = d.playing === true
                    ytmTitle = d.title || ""
                    ytmArtist = d.artist || ""
                    ytmArt = d.art || ""
                    var dur = parseFloat(d.durationSeconds) || 0
                    var prog = parseFloat(d.progressSeconds) || 0
                    ytmDuration = dur
                    ytmProgressSeconds = prog
                    ytmProgress = dur > 0 ? Math.round(prog / dur * 100) : 0
                } catch(e) {
                    ytmAvailable = false
                }
            }
        }
    }

    // Active power profile for PowerProfileMenu ("performance" / "balanced" / "power-saver")
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

    // Clipboard keyboard reader (work in progress, not started yet; see .claude/TODO.md)
    Process {
        id: clipboardProcess
        command: ["python3", scriptsDir + "/clipboard.py"]
        stdout: SplitParser {
            onRead: (line) => {
                const data = JSON.parse(line)
                root.clipboardRunning = data.running
                root.clipboardIndex = Math.max(0, Math.min(data.index, listView.count - 1))

                if (!data.running) {
                    // Enter was pressed: act on the selected entry, then close
                    selectEntry(root.clipboardIndex)
                }
            }
        }
    }

    // ── Timers ──

    // Current desktop
    Timer {
        interval: desktopPollMs; running: true; repeat: true
        onTriggered: {
            desktopProcess.running = false
            desktopProcess.running = true
        }
    }

    // Debounces bursts of pactl events into one volume/sink read
    Timer {
        id: volumeRefreshTimer
        interval: volumeDebounceMs
        onTriggered: {
            volumeProcess.running = true
            sinkProcess.running = true
        }
    }

    // Fallback poll for volume (in case an event is missed) and battery
    Timer {
        interval: fallbackPollMs; running: true; repeat: true
        onTriggered: {
            if (!volumeEventsProcess.running) volumeEventsProcess.running = true
            volumeProcess.running = true
            sinkProcess.running = true
            batteryProcess.running = true
        }
    }

    // App volumes, window list, power profile, music
    Timer {
        interval: slowPollMs; running: true; repeat: true
        onTriggered: {
            // App volumes are not refreshed while VolumeSlider is open (rebuilding the sliders mid-drag stutters)
            if (!shellRoot.activeVolumeScreen)
                appVolumesProcess.running = true

            if (shellRoot.activeWindowScreen)
                windowsProcess.running = true

            powerProfileProcess.running = true
            if (!ytmProcess.running) ytmProcess.running = true
        }
    }

    // First read of everything at startup
    Component.onCompleted: {
        desktopProcess.running = true
        volumeProcess.running = true
        sinkProcess.running = true
        volumeEventsProcess.running = true
        batteryProcess.running = true
        appVolumesProcess.running = true
        windowsProcess.running = true
        powerProfileProcess.running = true
        ytmProcess.running = true
        clipboardProcess = false    // Known bug (see .claude/TODO.md); keep this line last
    }

    // ── Windows: one of each per monitor ── remove a block to disable that feature

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

    Variants {
        model: Quickshell.screens
        YtmPanel {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        Clipboard {
            required property var modelData
            root: shellRoot
            screen: modelData
        }
    }
}
