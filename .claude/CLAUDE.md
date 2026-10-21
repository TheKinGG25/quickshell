# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For a deeper walkthrough (data flow diagrams, per-file responsibilities, polling intervals, known issues) see [`ARCHITECTURE.md`](../ARCHITECTURE.md) at the repo root.

## Running the shell

```bash
# Launch (from any directory)
quickshell -c /home/thekingg/.config/quickshell

# Or from within the config directory
quickshell
```

The polling `Process` commands in `shell.qml` use paths relative to the working directory (`.config/quickshell/scripts/...`, `.cache/ytmd-now.json`), so they only resolve when quickshell is started from `$HOME`. Other components still use absolute `/home/thekingg/...` paths.

There are no build steps - QML is interpreted at runtime. Changes take effect on the next `quickshell` launch.

The music player feed is **not** started by the shell. Run it separately (see "Music player" below):

```bash
ytmdesktop --remote-debugging-port=9222 --remote-allow-origins=*
python3 ~/.config/quickshell/scripts/ytmd-nowplaying.py
```

## Architecture overview

This is a Wayland desktop bar built with [QuickShell](https://quickshell.outfoxxed.me/) (QML-based shell framework) targeting KDE Plasma.

### State and data flow

`shell.qml` is the single root (`ShellRoot`, id `shellRoot`) that owns **all global state** as properties:

- Constants: `fontFamily`, `fontSize`, `barHeight`
- System: `currentDesktop`, `volumeLevel`, `volumeMuted`, `headphonesActive`, `batteryLevel`, `batteryStatus`, `powerProfile`, `appVolumes[]`, `windows[]`
- Music: `ytmAvailable`, `ytmPlaying`, `ytmTitle`, `ytmArtist`, `ytmArt`, `ytmProgress` (0-100), `ytmProgressSeconds`, `ytmDuration`
- Clipboard: `clipboardIndex`, `clipboardRunning` (fed by `clipboard.py`, work in progress)
- Layout helpers: `ytmPillLeftX` (x of the Right section, used to place YtmPanel under the pill), `rightLength` (currently unused)
- Popup visibility: `activeVolumeScreen`, `activePowerScreen`, `activePowerProfileScreen`, `activeWindowScreen`, `activeYtmScreen` (null = hidden, screen ref = show on that screen)

State is polled by timer-driven `Process` objects in `shell.qml` that run commands / Python scripts and read stdout via `SplitParser`. Every QML component receives `root: shellRoot` and reads state from it directly. Components never own shared state.

Polling cadence (all in `shell.qml`):

| Interval | What |
|----------|------|
| 100 ms | `wpctl get-volume`, bluetooth sink check, battery capacity + status |
| 200 ms | `kwin-desktop.py` (current desktop) |
| 500 ms | `kwin-windows.py` while WindowMenu is open |
| 1 s | `app-volumes.py` (skipped while VolumeSlider is open), `powerprofilesctl get`, `cat ~/.cache/ytmd-now.json` |

### Component instantiation

All top-level windows (Bar, VolumeSlider, PowerMenu, WindowMenu, PowerProfileMenu, YtmPanel, Clipboard) are created once **per screen** via:

```qml
Variants {
    model: Quickshell.screens
    Bar {
        required property var modelData
        root: shellRoot
        screen: modelData
    }
}
```

### Popup panel visibility pattern

Popup `PanelWindow`s live on `WlrLayer.Overlay` and use `visible: root && root.activeXScreen === screen`. Click handlers toggle the relevant `root.activeXScreen` between the current screen and null. Most panels close on `MouseArea.onExited`; YtmPanel is the exception and closes on click.

### Bar layout

`Bar.qml` → `Left | Center (centered) | Right`

- **Left.qml** - 6 virtual desktop numbers; clicking calls `kwin-desktop.py <number>`
- **Center.qml** - Clock with 12h arc indicator (blue AM / peach PM); left-click opens WindowMenu, middle-click opens PowerMenu
- **Right.qml** - Row of pills: `YtmPill | VolumePill | BatteryPill`

### Pill interactions

| Pill | Left click | Middle click | Right click | Scroll |
|------|-----------|--------------|-------------|--------|
| YtmPill | Toggle YtmPanel | - | - | - |
| VolumePill | Open VolumeSlider | Toggle Bluetooth headphones (`volume-toggle-bt.sh`) | Mute toggle | ±1% volume |
| BatteryPill | - | Open PowerProfileMenu | - | - |

### Popups

| File | Opened from | Content |
|------|-------------|---------|
| `VolumeSlider.qml` | VolumePill left click | Master slider + per-app sliders (`wpctl` / `pactl`) |
| `PowerMenu.qml` | Clock middle click | Lock / suspend / reboot / poweroff |
| `PowerProfileMenu.qml` | BatteryPill middle click | performance / balanced / power-saver |
| `WindowMenu.qml` | Clock left click | Open windows grouped by desktop; click focuses, F2 opens `EditDialogWindow.qml` |
| `YtmPanel.qml` | YtmPill left click | Album art, title, artist, elapsed / total time, progress bar |
| `Clipboard.qml` | nothing yet (`clipboardOpen` is never set) | WIP clipboard picker: 3 placeholder rows, highlighted row follows `root.clipboardIndex` |

### Scripts (`scripts/`)

Scripts are invoked by QML `Process` objects. They print JSON (or a plain value) to stdout which QML parses via `SplitParser`.

| Script | Usage | Purpose |
|--------|-------|---------|
| `kwin-desktop.py` | no args → print current desktop number; `<n>` → switch | KWin VirtualDesktopManager over DBus |
| `kwin-windows.py` | no args → print JSON window list; `<win_id>` → focus | KWin WindowsRunner + `icons.json` enrichment |
| `app-volumes.py` | prints JSON array of `{id, name, volume}` | per-app PulseAudio/PipeWire streams |
| `ytmd-nowplaying.py` | long-running daemon, started manually | Reads YouTube Music state over Chrome DevTools Protocol, writes `~/.cache/ytmd-now.json` every second |
| `save-icons-config.py` | `<app_id> <icon> <display_name>` | writes to `icons.json` |
| `add-to-blacklist.py` | `<app_id>` | adds to `icons.json` blacklist |
| `clipboard.py` | long-running, prints `{running, index}` per key press | Reads the keyboard via `evdev`: Up/Down move `index`, Enter prints `running: false` and exits |
| `volume-toggle-bt.sh` | no args | connect/disconnect headphones via `bluetoothctl` |
| `bt-config.sh` | sourced | defines `HEADPHONE_MAC` |

### Music player (YtmPill / YtmPanel)

Pipeline: `ytmdesktop` (Venipa ytmdesktop2, launched with `--remote-debugging-port=9222 --remote-allow-origins=*`) → `ytmd-nowplaying.py` evaluates JS in the `music.youtube.com` page via CDP websocket → writes one JSON line to `~/.cache/ytmd-now.json` → `shell.qml` `ytmProcess` runs `cat .cache/ytmd-now.json` (relative to the working directory) every second → `ytm*` properties.

JSON fields used by QML: `available`, `playing`, `title`, `artist`, `art`, `durationSeconds`, `progressSeconds`. The script also emits `state`, `videoId`, `thumbnails`, `queue[]`, `queueSource` which the UI does not use yet.

YtmPill is hidden when `ytmAvailable` is false (no file, bad JSON, `available: false`, or empty title). The display is read-only: there are no playback controls.

### App icon/name configuration (`scripts/icons.json`)

The window list enrichment pipeline in `kwin-windows.py` looks up each window's `resourceClass` (e.g. `code`, `brave-origin-beta`) in `icons.json`:

```json
{
  "iconMappings": {
    "resourceClass": { "icon": "icon-name-or-path", "displayName": "Human Name" }
  },
  "blacklist": ["org.quickshell"]
}
```

- `icon` can be a system icon name (resolved via `image://icon/`) or an absolute file path
- Apps in `blacklist` are filtered out of WindowMenu
- Edit entries from the UI: hover an app in WindowMenu → press **F2** → EditDialogWindow opens

### External dependencies

- `qdbus6` - KWin virtual desktop and window info over DBus
- `wpctl` - WirePlumber master audio control
- `pactl` - per-app audio stream volumes
- `bluetoothctl` - headphone connect toggle
- `powerprofilesctl` - power profile get/set
- `systemctl` / `loginctl` - power menu actions
- `ytmdesktop` + `python-websocket-client` + `python-requests` - music player feed
- `python-evdev` - keyboard input for `clipboard.py` (needs read access to `/dev/input/event*`)
- `JetBrainsMono Nerd Font` - required for all icons (Nerd Font codepoints used throughout)

Paths in QML `Process` commands are either hardcoded to `/home/thekingg/.config/quickshell/...` (pills, menus) or relative to `$HOME` (`shell.qml` pollers).

### Color theme

Mostly Catppuccin Mocha: `#11111b` (base), `#1e1e2e` (crust), `#313244` (surface), `#cdd6f4` (text), `#89b4fa` (blue), `#cba6f7` (mauve), `#fab387` (peach). Pills use their own status colors (battery green→red, volume blue/pink/grey, YTM red `#ff4444`).
