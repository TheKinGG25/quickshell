# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the shell

```bash
# Launch (from any directory)
quickshell -c /home/thekingg/.config/quickshell

# Or from within the config directory
quickshell
```

There are no build steps — QML is interpreted at runtime. Changes take effect on the next `quickshell` launch.

## Architecture overview

This is a Wayland desktop bar built with [QuickShell](https://quickshell.outfoxxed.me/) (QML-based shell framework) targeting KDE Plasma.

### State and data flow

`shell.qml` is the single root (`ShellRoot`) that owns **all global state** as properties:

- `currentDesktop`, `volumeLevel`, `volumeMuted`, `headphonesActive`
- `batteryLevel`, `batteryStatus`, `powerProfile`
- `appVolumes[]`, `windows[]`
- `ytmTitle`, `ytmArtist`, `ytmThumbnailUrl`, `ytmAccent`, `ytmPlaying`, `ytmProgress`
- `activeVolumeScreen`, `activePowerScreen`, `activePowerProfileScreen`, `activeWindowScreen` — controls which popup panel is visible on which screen (null = hidden, screen ref = show on that screen)

State is polled by timer-driven `Process` objects in `shell.qml` that run Python scripts and read stdout. Every QML component receives `root: shellRoot` (the `ShellRoot` instance) and reads state from it directly.

### Component instantiation

All top-level components (Bar, VolumeSlider, PowerMenu, WindowMenu, PowerProfileMenu) are created once **per screen** via:

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

Popup `PanelWindow`s use `visible: root && root.activeXScreen === screen`. Click handlers toggle the relevant `root.activeXScreen` between the current screen and null. Panels close on `MouseArea.onExited`.

### Bar layout

`Bar.qml` → `Left | [spacer] | Center | [spacer] | Right`

- **Left.qml** — 6 virtual desktop buttons; clicking calls `kwin-desktop.py <number>`
- **Center.qml** — Clock with 12h arc indicator; left-click opens WindowMenu, middle-click opens PowerMenu
- **Right.qml** — Row of pills: `YtmPill | VolumePill | BatteryPill`

### Pill interactions

| Pill | Left click | Middle click | Right click | Scroll |
|------|-----------|--------------|-------------|--------|
| VolumePill | Open VolumeSlider | Toggle Bluetooth output | Mute toggle | ±1% volume |
| BatteryPill | — | Open PowerProfileMenu | — | — |
| YtmPill | — | — | — | — |

### Python scripts (`scripts/`)

Scripts are invoked by QML `Process` objects. They print JSON (or a plain value) to stdout which QML parses via `SplitParser`.

| Script | Mode | Purpose |
|--------|------|---------|
| `kwin-desktop.py` | no args → print current desktop number | called with `<n>` to switch desktop |
| `kwin-windows.py` | no args → print JSON window list | called with `<win_id>` to focus window |
| `app-volumes.py` | prints JSON array of `{id, name, volume}` | per-app PulseAudio/PipeWire streams |
| `ytm-track.py` | prints JSON `{title, author, thumbnail, accent}` | polls `localhost:13091` (ytmdesktop) |
| `ytm-state.py` | prints JSON `{playing, percentage}` | polls `localhost:13091` |
| `save-icons-config.py` | `<app_id> <icon> <display_name>` | writes to `icons.json` |
| `add-to-blacklist.py` | `<app_id>` | adds to `icons.json` blacklist |

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

- `qdbus6` — KWin virtual desktop and window info over DBus
- `wpctl` — WirePlumber master audio control
- `pactl` — per-app audio stream volumes
- `powerprofilesctl` — power profile get/set
- YouTube Music Desktop running at `localhost:13091` (YtmPill is hidden when no track is playing)
- `JetBrainsMono Nerd Font` — required for all icons (Nerd Font codepoints used throughout)

### Color theme

Catppuccin Mocha palette used throughout: `#11111b` (base), `#1e1e2e` (crust), `#313244` (surface), `#cdd6f4` (text), `#89b4fa` (blue), `#cba6f7` (mauve), etc.
