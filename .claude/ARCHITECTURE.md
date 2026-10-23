# Architecture

A QuickShell (QML) top bar for Wayland, running on both KDE Plasma (KWin) and Hyprland. No build
step: `quickshell` interprets the QML at launch, reads what it can over IPC, and shells out to
small Python / Bash helpers for the rest.

## 1. Big picture

```
   system tools            compositor                 YouTube Music Desktop 2
   (wpctl, pactl,          KWin: qdbus6 scripts       HTTP API on 127.0.0.1:13091
    sysfs, bluetoothctl)   Hyprland: Quickshell.Hyprland (events) + hyprctl
            │                        │                          │
            ▼                        ▼                          ▼
   ┌──────────────────────── shell.qml (ShellRoot, id shellRoot) ────────────────────────┐
   │  Process + SplitParser, XMLHttpRequest, Hyprland bindings                           │
   │                                                                                     │
   │  state:   currentDesktop, volume*, battery*, powerProfile, appVolumes[], windows[], │
   │           ytm* (title, art, progress, volume, queue[]), clipboard*                  │
   │  facts:   hyprland / compositor, windowsScript, ytmPillGeom (per monitor)           │
   │  actions: switchDesktop(n), focusWindow(id), refreshWindows(), ytmCommand(),        │
   │           ytmSetVolume(), ytmFetchQueue()                                           │
   │  popups:  active{Volume,Power,PowerProfile,Window,Ytm}Screen, debugPopups           │
   └───────────────────────────────────┬─────────────────────────────────────────────────┘
                                       │ root: shellRoot   (passed to every component)
            Variants { model: Quickshell.screens } → one copy of each window per monitor
                                       │
   ┌──────────────┬──────────────┬─────┴────────┬──────────────────┬──────────┬───────────┐
   Bar         VolumeSlider   PowerMenu     PowerProfileMenu   WindowMenu   YtmPanel   Clipboard
   │                                                            └─ EditDialogWindow
   ├─ Left    (desktop / workspace numbers)
   ├─ Center  (clock + arc)
   └─ Right   (YtmPill | VolumePill | BatteryPill)
```

Rules the code follows:

1. **One source of truth.** All shared state lives on `ShellRoot`. Components read it and write
   only the `active*Screen` flags. Anything used by more than one file belongs there.
2. **Poll what cannot push.** Most system values are polled: a `Timer` sets `process.running =
   true`, the process prints to stdout, a `SplitParser.onRead` assigns a property, bindings do the
   rest. Three sources push instead and have no timer: `pactl subscribe` (audio), the Hyprland
   workspace grid file `hypr-grid.json` (a watched `FileView`), and nothing else. The music API is polled
   over HTTP rather than by a process.
3. **Per-screen windows, global flags.** Each window exists on every screen and shows itself only
   when `root.activeXScreen === screen`, so a popup opens on the monitor whose bar was clicked.
   A value that differs per monitor must be keyed by `screen.name` (see `ytmPillGeom`), because a
   single property would be overwritten by every screen's copy of the window that writes it.
4. **Compositor differences live in `shell.qml`.** `root.hyprland` decides, and the rest of the
   tree calls one function: `switchDesktop()`, `focusWindow()`, `windowsScript`. No other file
   branches on the compositor.
5. **Side effects go through `Process` or an API call.** Component-local actions (mute, power
   profile, bluetooth) own their own `Process`; anything compositor-specific or shared goes through
   a `shell.qml` function.

## 2. Files

### QML

| File | Kind | Responsibility |
|------|------|----------------|
| `shell.qml` | `ShellRoot` | Global state, compositor detection, every poller and timer, the music API client, instantiates each window per screen |
| `Bar.qml` | `PanelWindow` (Top layer, top/left/right) | `root.barHeight` (30px) translucent strip holding Left / Center / Right. Publishes its own screen's YtmPill position through `setYtmPillGeom()` so YtmPanel knows where to grow from |
| `Left.qml` | `Row` | `root.desktopCount` desktop / workspace numbers, current one white and bold, on Hyprland labelled `[n,m]` with this screen's m (`root.gridM`). Click → `root.switchDesktop(n)` |
| `Overview.qml` | `PanelWindow` (Overlay, full screen, no keyboard focus), Hyprland only | Meta+Tab exploded view of this screen's workspace grid from `root.hyprGrid`: live window previews (`ScreencopyView`) per `[n,m]`, current one outlined, current n in the middle column, every column's bar workspace on the middle row, empty workspaces hidden, `zoom` workspaces across. Click → `root.gridGo()` |
| `Center.qml` | `MouseArea` | Canvas ring showing progress through the 12h half-day (blue AM, peach PM) + `hh:mm:ss AP \| dddd - dd/MM/yy`. Left click → WindowMenu (KWin only), middle → PowerMenu |
| `Right.qml` | `Row` | `YtmPill`, `VolumePill`, `BatteryPill` |
| `YtmPill.qml` | `Rectangle`, `ytmWidth` x `pillHeight` (280x22) | Cover thumbnail, title, artist, 2px progress line. Hidden unless `ytmAvailable`, and transparent while YtmPanel is open on this screen. Click toggles the panel, scroll changes the app's volume |
| `YtmPanel.qml` | `PanelWindow` (Overlay, starts at the screen top with `ExclusionMode.Ignore` + a `mask`) | The music player. One `morph` value (0..1) grows the pill into a 280x448 card centered on it, crossfading a copy of the pill into the content; a 56px side card of buttons sits below the bar beside it. Cover flips to the queue, side card flips to a vertical volume slider, blurred cover art behind both |
| `VolumePill.qml` | `ValuePill` | Volume number + icon. Color: grey muted / pink bluetooth / blue speakers. Left: VolumeSlider, middle: bluetooth toggle, right: mute, wheel: ±`volumeStep` |
| `VolumeSlider.qml` | `PanelWindow` (Overlay, top-right) | Master slider (`wpctl`) and one slider per app stream (`pactl`) |
| `BatteryPill.qml` | `ValuePill` | Percent + arrow (↑ charging, ↓ discharging, - plugged but not charging). Color steps every 20%. Middle click → PowerProfileMenu |
| `PowerProfileMenu.qml` | `PanelWindow` (Overlay, top-right) | One row per entry in its `profiles` list, click runs `powerprofilesctl set <profile>` |
| `PowerMenu.qml` | `PanelWindow` (Overlay, centered) | One button per entry in its `buttons` list (icon, label, color, command): shutdown / restart / sleep / lock |
| `WindowMenu.qml` | `PanelWindow` (Overlay, centered, keyboard OnDemand) | Desktop tabs (`root.desktopCount`) + the windows on the selected one, from `root.windows`. Click → `root.focusWindow(id)`. F2 on a hovered row opens EditDialogWindow. Closes 200ms after the mouse leaves, unless the dialog is open |
| `Clipboard.qml` | `PanelWindow` (top-right, keyboard Exclusive) | WIP clipboard picker. Three placeholder rows, the one at `root.clipboardIndex` highlighted. Visible only when its own `clipboardOpen` is true, which nothing sets yet |
| `EditDialogWindow.qml` | `Window` | Edit the icon and display name for a window class, or blacklist it. Writes through `save-icons-config.py` / `add-to-blacklist.py`, then calls `root.refreshWindows()` |

### Components (`components/`)

Shared building blocks, imported with `import "components"`.

| File | What it is | Used by |
|------|------------|---------|
| `SliderTrack.qml` | "filled \| gap \| handle \| gap \| empty" bar for a `position` 0..1; `vertical` fills from the bottom | VolumeBarSlider (as its background), YtmPanel's volume slider |
| `VolumeBarSlider.qml` | Slider (0..100 by default, any range) with a SliderTrack background, a thin handle and a scroll wheel; `onMoved` covers both drag and scroll | VolumeSlider (master + apps), YtmPanel seek bar |
| `IconButton.qml` | Square button showing one Nerd Font `glyph`, with an `active` color and a state-layer hover / press | YtmPanel controls and side card |
| `ValuePill.qml` | Colored pill, value text left, icon right | VolumePill, BatteryPill |
| `PopupCard.qml` | Dark rounded card with a border, theme colors | VolumeSlider, PowerMenu, PowerProfileMenu, WindowMenu, Clipboard, EditDialogWindow |
| `DialogButton.qml` | Flat button with a hover color | EditDialogWindow |
| `HoverDebug.qml` | Translucent outline of a popup's hover area, drawn only while `root.debugPopups` | every popup |

### Scripts (`scripts/`)

Each prints JSON or a plain value on stdout, which QML parses in a `SplitParser`.

| Script | Called by | In → Out |
|--------|-----------|----------|
| `kwin-desktop.py` | `shell.qml` (200ms, KWin only), `switchDesktop()` | none → `3`; `<n>` → switches desktop |
| `kwin-windows.py` | `shell.qml` (500ms while WindowMenu is open, KWin only), `focusWindow()` | none → JSON window list enriched from `icons.json`; `<id>` → focus that window |
| `hypr-windows.py` | nothing at the moment (WindowMenu does not open under Hyprland) | `hyprctl clients -j` → the same JSON window list (focusing is done in QML) |
| `window_icons.py` | imported by both window scripts | shared `icons.json` loading, class → icon / display name lookup, blacklist |
| `app-volumes.py` | `shell.qml` (1s) | → `[{id, name, volume}]` parsed from `pactl list sink-inputs` |
| `save-icons-config.py` | `EditDialogWindow.qml` | `<app_id> <icon> <name>` → updates `icons.json` |
| `add-to-blacklist.py` | `EditDialogWindow.qml` | `<app_id>` → appends to the `icons.json` blacklist |
| `clipboard.py` | `shell.qml` `clipboardProcess` (never started yet) | Reads the first keyboard via `evdev`; prints `{running, index}` on Up / Down, prints `running: false` and exits on Enter |
| `volume-toggle-bt.sh` + `bt-config.sh` | `VolumePill.qml` | connect / disconnect `HEADPHONE_MAC` |
| `icons.json` | `window_icons.py` | `iconMappings` keyed by the window class, plus `blacklist` |

Script paths all come from `root.scriptsDir` (`Quickshell.env("HOME") + "/.config/quickshell/scripts"`),
so the launch directory does not matter.

## 3. Compositor support

`shell.qml` sets `readonly property bool hyprland` from `Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")`,
which Hyprland exports to every client. Everything workspace- or window-related asks it:

| | KWin (Plasma) | Hyprland |
|---|---|---|
| Current desktop | `kwin-desktop.py` polled every `desktopPollMs` | `hyprGrid.n`, read from `$XDG_RUNTIME_DIR/hypr-grid.json` (a `FileView` with `watchChanges`), no polling (the poll timer is off) |
| Switching | `kwin-desktop.py <n>` | `Hyprland.dispatch(...)` calling `grid.switch_n(n)` in `~/.config/hypr/grid.lua` |
| Desktop label | `n` | `[n,m]`, m from `gridM(screen.name, n)`: per screen, current m for the active n, last visited m for the rest |
| Window list | `kwin-windows.py` | none: WindowMenu does not open under Hyprland (its tabs are desktop numbers, grid ids are not) |
| Focusing a window | `kwin-windows.py <id>` | `Hyprland.dispatch(...)` with the window address |

Hyprland's dispatch syntax depends on its config language. Quickshell sends the string as
`return hl.dispatch(<string>)`, so with a Lua config (`Hyprland.usingLua`) a bare `"workspace 3"`
is a Lua syntax error; `hl.dispatch` takes a dispatcher object or a function. `switchDesktop()`
sends `function() grid.switch_n(n) end` into `~/.config/hypr/grid.lua` (the 2D workspace grid:
`[n,m]`, n global across monitors, m per monitor, state in `$XDG_RUNTIME_DIR/hypr-grid.json`), and
`focusWindow()` sends `hl.dsp.focus{window="address:..."}`. Non-Lua Hyprland takes plain strings.

Window classes differ between the two (KWin reports `code`, Hyprland `com.microsoft.VSCode`), so an
`icons.json` mapping saved in one session does not necessarily apply in the other; the file simply
gains an entry per class.

## 4. Polling and events

| Every | Source | Property |
|-------|--------|----------|
| event | `pactl subscribe` (long-running). A `sink` or `server` event restarts a 30ms debounce timer that runs the two reads below | |
| event + 2s | `wpctl get-volume @DEFAULT_AUDIO_SINK@` | `volumeLevel`, `volumeMuted` |
| event + 2s | `wpctl inspect ... \| grep -c api.bluez5.address` | `headphonesActive` |
| file change | `$XDG_RUNTIME_DIR/hypr-grid.json`, written by `~/.config/hypr/grid.lua` (Hyprland only) | `hyprGrid`, `currentDesktop` |
| 2s | `sh -c` loop over `/sys/class/power_supply/BAT*`, first match: `capacity` then `status` | `batteryLevel`, `batteryStatus` |
| 200ms | `kwin-desktop.py` (KWin only) | `currentDesktop` |
| 500ms | `root.windowsScript` (only while WindowMenu is open) | `windows` |
| 1s | `app-volumes.py` (only while VolumeSlider is closed) | `appVolumes` |
| 1s | `powerprofilesctl get` | `powerProfile` |
| 500ms, 2s when unreachable | `GET /track/state` on the music API (+ `GET /track` when the track id changes) | `ytm*` |
| 100ms | no process: moves `ytmProgressSeconds` forward locally between polls while playing | `ytmProgress*` |

The 2s timer also restarts `pactl subscribe` if it exits. Array properties are only reassigned when
`JSON.stringify` differs, to avoid needless re-layout of lists.

## 5. Music player pipeline

```
YouTube Music Desktop 2 (ytmdesktop2), API on http://127.0.0.1:13091
   ▲  POST /track/<cmd>      toggle-play-state, next, prev, seek, like, dislike, shuffle, repeat
   │  POST /track/volume     {volume} to set, no body to read back
   │        ▲ root.ytmCommand() / ytmSetVolume() / ytmNudgeVolume()  ◄── YtmPanel, YtmPill scroll
   │
   ▼  GET /track/state   every 500ms (2s while unreachable)
   ▼  GET /track         when the track id changes (title, artist, videoId)
   ▼  GET /nav/queue     when the queue overlay is opened, and on track change after that
shell.qml ytmPoll() / ytmFetchQueue()   (XMLHttpRequest, no helper script)
   ▼
ShellRoot.ytm*  ──►  YtmPill (bar)  ──click──►  YtmPanel (player card)
                      cover art: GET /track/thumbnail?id=<videoId>, served from the app's own cache
```

`ytmAvailable` is false when the API does not answer, `/track/state` is null, or the track has no
title. Volume is not part of `/track/state`, so it is read from the volume endpoint instead.

## 6. Known issues and TODO

Bugs, unfinished features and cleanups, with priority scores, are tracked in [`TODO.md`](TODO.md).
