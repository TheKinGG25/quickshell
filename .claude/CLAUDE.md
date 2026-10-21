# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Docs live in `.claude/`:

- [`ARCHITECTURE.md`](ARCHITECTURE.md) - deeper walkthrough: data flow diagrams, per-file responsibilities, polling intervals, music pipeline
- [`TODO.md`](TODO.md) - bugs, unfinished features and cleanups with a priority score. Update it when you fix or find something.

Keep every Markdown file for this project inside `.claude/`.

## Where to change things

Every file starts with a comment saying what it is, how it is opened and where its data comes from. Right after `property var root` most QML files have a `// ── Tweakables ──` block: sizes, colors, texts and timings for that file only. Shared values live in `shell.qml`.

| I want to change... | Go to |
|---------------------|-------|
| A theme color used in several places (popup background, text, accent) | `shell.qml` → "Theme" |
| Font, bar height, pill height / radius, number of desktops, music pill width | `shell.qml` → "Fonts" / "Layout" |
| How often something refreshes | `shell.qml` → "Polling intervals" |
| Where scripts or the music cache file live | `shell.qml` → "Paths" |
| Clock format, ring colors | `Center.qml` → Tweakables |
| Desktop number colors / spacing | `Left.qml` → Tweakables |
| Pill order | `Right.qml` |
| A pill's colors, icons, scroll step | `VolumePill.qml` / `BatteryPill.qml` / `YtmPill.qml` → Tweakables |
| Layout of the volume / battery pills (padding, min width, fonts) | `components/ValuePill.qml` |
| Look of every slider and the music progress bar (gap, handle, radius) | `components/SliderTrack.qml`, `components/VolumeBarSlider.qml` |
| Look of every popup card | `components/PopupCard.qml` (colors: `shell.qml` Theme) |
| Power menu buttons (add, remove, command, icon) | `PowerMenu.qml` → `buttons` list |
| Power profiles shown | `PowerProfileMenu.qml` → `profiles` list |
| A popup's size, radius, offsets | that popup's Tweakables |
| App icon / name in WindowMenu | `scripts/icons.json` (or F2 in WindowMenu) |
| Headphone MAC | `scripts/bt-config.sh` |
| Music feed port / output file / rate | top of `scripts/ytmd-nowplaying.py` |

Conventions when adding code:

- On a `PanelWindow` set `implicitWidth` / `implicitHeight`, not `width` / `height` (Quickshell warns that those are deprecated).

- UI that appears more than once becomes a component in `components/` (imported with `import "components"`). Give it named properties for everything it needs; components do not see the caller's scope, so pass `root: <windowId>.root`, never `root: root`.
- A value used in more than one file goes in `shell.qml` and is read as `root.<name>`.
- A value used in one file goes in that file's Tweakables block, referenced as `<fileRootId>.<name>` (qualified, so a child's own `color` / `width` cannot shadow it).
- Nerd Font icons in lists are written as code point escapes (`"\uf011"`, `"\u{f04b2}"`) so they survive copy-paste.

## Running the shell

```bash
# Launch (from any directory)
quickshell -c /home/thekingg/.config/quickshell

# Or from within the config directory
quickshell
```

All script paths come from `root.scriptsDir` (`$HOME/.config/quickshell/scripts`) and `root.homeDir`, defined once in `shell.qml`, so the launch directory does not matter.

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
- Layout helpers: `ytmPillLeftX` (x of the Right section, used to place YtmPanel under the pill)
- Popup visibility: `activeVolumeScreen`, `activePowerScreen`, `activePowerProfileScreen`, `activeWindowScreen`, `activeYtmScreen` (null = hidden, screen ref = show on that screen)

State is polled by timer-driven `Process` objects in `shell.qml` that run commands / Python scripts and read stdout via `SplitParser`. Every QML component receives `root: shellRoot` and reads state from it directly. Components never own shared state.

Polling cadence (all in `shell.qml`):

| Interval | What |
|----------|------|
| event | `pactl subscribe` (long-running): any sink/server change triggers `wpctl get-volume` + bluetooth sink check, debounced 30 ms |
| 2 s | fallback volume + sink read, battery (first `/sys/class/power_supply/BAT*`), restart `pactl subscribe` if it died |
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

### Reusable components (`components/`)

| File | What it is | Used by |
|------|------------|---------|
| `SliderTrack.qml` | "filled \| gap \| handle \| gap \| empty" bar for a `position` 0..1 | VolumeBarSlider, YtmPanel progress |
| `VolumeBarSlider.qml` | 0..100 slider: SliderTrack background, thin handle, scroll wheel (`onMoved` on drag and scroll) | VolumeSlider (master + apps) |
| `ValuePill.qml` | colored pill, value text left, icon right | VolumePill, BatteryPill |
| `PopupCard.qml` | dark rounded card with border, theme colors | VolumeSlider, PowerMenu, PowerProfileMenu, WindowMenu, Clipboard, EditDialogWindow |
| `DialogButton.qml` | flat button with hover color | EditDialogWindow |

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

Pipeline: `ytmdesktop` (Venipa ytmdesktop2, launched with `--remote-debugging-port=9222 --remote-allow-origins=*`) → `ytmd-nowplaying.py` evaluates JS in the `music.youtube.com` page via CDP websocket → writes one JSON line to `~/.cache/ytmd-now.json` → `shell.qml` `ytmProcess` runs `cat ~/.cache/ytmd-now.json` every second → `ytm*` properties.

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

QML `Process` commands build script paths from `root.scriptsDir`; never hardcode `/home/...` paths in components.

### Color theme

Catppuccin Mocha, defined once in `shell.qml` → "Theme" (`root.popupBg`, `root.colText`, `root.colBlue`, ...). Pills keep their own status colors in their Tweakables (battery green→red, volume blue/pink/grey, YTM red `#ff4444`). `EditDialogWindow.qml` and `Clipboard.qml` still use their own literal colors.
