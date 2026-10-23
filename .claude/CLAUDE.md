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
| Where scripts live | `shell.qml` → "Paths" |
| Music API address / token / poll rate | `shell.qml` → "Music" |
| Clock format, ring colors | `Center.qml` → Tweakables |
| Desktop number colors / spacing | `Left.qml` → Tweakables |
| How a workspace switch is sent | `shell.qml` → `switchDesktop()` (branches on `root.hyprland`) |
| How a window is focused | `shell.qml` → `focusWindow()` (branches on `root.hyprland`) |
| Hyprland workspace grid ([n,m] ids, keybinds, monitor hotplug) | `~/.config/hypr/grid.lua` (Hyprland config, not this repo) |
| Look of the Meta+Tab workspace overview (colors, gap, radius, animation) | `Overview.qml` → Tweakables |
| Overview keys / zoom range (Meta+Tab, arrows, Ctrl+= / Ctrl+-, Enter / Escape) | `~/.config/hypr/keybinds.lua` ("overview" submap), `grid.lua` → `ZOOM_*` |
| See each popup's hover area on screen | `shell.qml` → `debugPopups: true` |
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
| Music player layout, icons, side buttons | `YtmPanel.qml` → Tweakables (`sideButtons` list) |
| Music player colors | `YtmPanel.qml` → "Colors": `accent` (red), `ink` (on the red), `active`; the rest derive from them |
| Blurred cover art behind the player | `YtmPanel.qml` → `artBgStrength` (0 = off), `artBgBlur`, `artBgLift` |
| How many upcoming tracks the queue lists | `shell.qml` → `ytmQueueMax` |

Conventions when adding code:

- On a `PanelWindow` set `implicitWidth` / `implicitHeight`, not `width` / `height` (Quickshell warns that those are deprecated).

- UI that appears more than once becomes a component in `components/` (imported with `import "components"`). Give it named properties for everything it needs; components do not see the caller's scope, so pass `root: <windowId>.root`, never `root: root`.
- A value used in more than one file goes in `shell.qml` and is read as `root.<name>`.
- A value that differs **per monitor** must be stored per screen, keyed by `screen.name` (like `ytmPillGeom`): a single shared property gets overwritten by every screen's copy of the window that writes it. Reassign the whole object (`geom = next`), since QML does not notice a change made inside a `var`.
- A value used in one file goes in that file's Tweakables block, referenced as `<fileRootId>.<name>` (qualified, so a child's own `color` / `width` cannot shadow it).
- Do not declare a property whose name the base type already has (e.g. `icon`, `text`, `padding` on a `Button`): Qt refuses FINAL ones with "Cannot override FINAL property". `IconButton` uses `glyph` for that reason.
- Name one variable per actual color, not per use site. YtmPanel has three (`accent`, `ink`, `active`) and derives its shades (`inkWash`, `accentDark`), so a recolor is a one-line change; it used to carry ten names for the same three colors. `Qt.alpha()` does not exist in this Qt: fade a color with `Qt.rgba(c.r, c.g, c.b, a)`.
- Never name a property `onSomething`: QML reads it as a signal handler ("Cannot assign a value to a signal").
- Hover / press on `IconButton` is a state layer (its icon color at `hoverOpacity` / `pressedOpacity` over `baseColor`), so callers pass no hover color.
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

The music player needs YouTube Music Desktop 2 running with its API enabled (port 13091). Nothing else to start.

## Architecture overview

This is a Wayland desktop bar built with [QuickShell](https://quickshell.outfoxxed.me/) (QML-based shell framework) targeting KDE Plasma.

### State and data flow

`shell.qml` is the single root (`ShellRoot`, id `shellRoot`) that owns **all global state** as properties:

- Constants: `fontFamily`, `fontSize`, `barHeight`
- Compositor: `hyprland` (bool), `compositor` ("Hyprland" / "KWin"), `windowsScript`, `hyprGrid` (Hyprland workspace grid state), plus `switchDesktop(n)`, `focusWindow(id)`, `gridM(screenName, n)`, `gridGo(screenName, n, m)`, `closeOverview()`, `refreshWindows()`
- Debug: `debugPopups` (draws each popup's hover area)
- System: `currentDesktop`, `volumeLevel`, `volumeMuted`, `headphonesActive`, `batteryLevel`, `batteryStatus`, `powerProfile`, `appVolumes[]`, `windows[]`
- Music: `ytmAvailable`, `ytmPlaying`, `ytmTitle`, `ytmArtist`, `ytmArt`, `ytmProgress` (0-100), `ytmProgressSeconds`, `ytmDuration`, `ytmVideoId`, `ytmLiked`, `ytmDisliked`, `ytmLoop`, `ytmVolume` (0-100), `ytmQueue[]`; functions `ytmCommand(cmd, body)`, `ytmReadVolume()`, `ytmSetVolume(v)`, `ytmNudgeVolume(up)`, `ytmFetchQueue()`
- Clipboard: `clipboardIndex`, `clipboardRunning` (fed by `clipboard.py`, work in progress)
- Layout helpers: `ytmPillGeom` (YtmPill's position in the bar **per monitor**, `{"DP-1": {x, y}}`, written by each screen's Bar through `setYtmPillGeom(screenName, x, y)`), `ytmPanelScreen` (screen whose YtmPanel is showing; YtmPill hides there)
- Popup visibility: `activeVolumeScreen`, `activePowerScreen`, `activePowerProfileScreen`, `activeWindowScreen`, `activeYtmScreen` (null = hidden, screen ref = show on that screen)

State is polled by timer-driven `Process` objects in `shell.qml` that run commands / Python scripts and read stdout via `SplitParser`. Every QML component receives `root: shellRoot` and reads state from it directly. Components never own shared state.

Polling cadence (all in `shell.qml`):

| Interval | What |
|----------|------|
| event | `pactl subscribe` (long-running): any sink/server change triggers `wpctl get-volume` + bluetooth sink check, debounced 30 ms |
| 2 s | fallback volume + sink read, battery (first `/sys/class/power_supply/BAT*`), restart `pactl subscribe` if it died |
| 200 ms | `kwin-desktop.py` (current desktop) - **KWin only**, Hyprland pushes events instead |
| 500 ms | `root.windowsScript` (`kwin-windows.py` or `hypr-windows.py`) while WindowMenu is open |
| 1 s | `app-volumes.py` (skipped while VolumeSlider is open), `powerprofilesctl get` |
| 500 ms (2 s idle) | music API `GET /track/state` (+ `GET /track` on track change) |

### Component instantiation

All top-level windows (Bar, VolumeSlider, PowerMenu, WindowMenu, PowerProfileMenu, YtmPanel, Clipboard, and Overview under Hyprland) are created once **per screen** via:

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

Popup `PanelWindow`s live on `WlrLayer.Overlay` and use `visible: root && root.activeXScreen === screen`. Click handlers toggle the relevant `root.activeXScreen` between the current screen and null. Panels close on `MouseArea.onExited`.

### Compositor support (Plasma / Hyprland)

The workspace selector works on both. `shell.qml` sets `readonly property bool hyprland` from
`Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")`, which Hyprland exports to every client, and
everything workspace-related branches on it:

| | KWin (Plasma) | Hyprland |
|---|---|---|
| Current desktop | `kwin-desktop.py` polled every `desktopPollMs` | `hyprGrid.n`, read from `$XDG_RUNTIME_DIR/hypr-grid.json` (a `FileView` with `watchChanges`), no polling (the poll timer is off) |
| Switching | `kwin-desktop.py <n>` | `Hyprland.dispatch(...)` calling `grid.switch_n(n)` in `~/.config/hypr/grid.lua` |
| Desktop label | `n` | `[n,m]`, m from `gridM(screen.name, n)`: per screen, current m for the active n, last visited m for the rest |
| Window list | `kwin-windows.py` | none: WindowMenu does not open under Hyprland (its tabs are desktop numbers, grid ids are not) |
| Focusing a window | `kwin-windows.py <id>` | `Hyprland.dispatch(...)` with the window address |

Hyprland runs a 2D workspace grid, defined in `~/.config/hypr/grid.lua`: workspace `[n,m]`, n = 1..6
switched on every monitor at once, m per monitor (Hyprland id = `monitor_index*10000 + n*1000 + m`).
grid.lua rewrites `$XDG_RUNTIME_DIR/hypr-grid.json` on every change:
`{"n": 2, "overview": {"open": false, "zoom": 3}, "screens": {"eDP-2": {"index": 0, "m": [m per n],
"rows": [stack + empty slot per n]}}}`. `shell.qml` watches it into `hyprGrid`; `Left.qml` labels
each number `[n,m]` for its own screen through `root.gridM()`.

**Overview (Meta+Tab).** `Overview.qml` is an Overlay-layer window per screen that draws that
screen's grid while `hyprGrid.overview.open`: columns n = 1..6, the current n in the middle; each
column slides so the workspace its bar label shows (`m[n]`) sits on the middle row, and empty
workspaces are not drawn. Live window previews from `ScreencopyView` on each `HyprlandToplevel.wayland`, placed
from `lastIpcObject.at` / `size` (refreshed with `Hyprland.refreshToplevels()` on Hyprland events
while open). `zoom` = workspaces visible across (3 = 100%). The keys are all in Hyprland: Meta+Tab
calls `grid.toggle_overview()`, which also enters the `overview` submap: arrows move through the
grid (`grid.step_n`, `grid.browse_m`, which skips empty workspaces), Ctrl+= / Ctrl+- zoom
(`grid.zoom`), Enter / Escape / Meta+Tab close, and a `catchall` bind swallows every other key so
neither the focused window nor the normal binds see it. The window takes no keyboard focus. A click on a workspace calls `root.gridGo()`, the
backdrop `root.closeOverview()`.

**Dispatch syntax depends on the Hyprland config language.** Quickshell sends the string as
`return hl.dispatch(<string>)`. With a Lua config (`Hyprland.usingLua`, true on 0.56 here) a bare
`"workspace 3"` is a Lua syntax error. `hl.dispatch` takes a dispatcher object or a function, so
`switchDesktop()` sends `function() grid.switch_n(3) end` (grid.lua sets the global `grid`) and
`focusWindow()` sends `hl.dsp.focus{window="address:..."}`; older non-Lua Hyprland takes the plain
strings.

Both window-list scripts share `scripts/window_icons.py` for the `icons.json` lookup, so F2
editing works the same on either compositor (`hypr-windows.py` is unused while WindowMenu stays
off under Hyprland). Note the class names differ between them (KWin says
`code`, Hyprland says `com.microsoft.VSCode`), so a mapping saved on one session does not
necessarily apply on the other; `icons.json` just gains an entry per class.

`desktopCount` is a fixed 6 on both, matching grid.lua's 6 horizontal workspaces.

### Bar layout

`Bar.qml` → `Left | Center (centered) | Right`

- **Left.qml** - `root.desktopCount` desktop / workspace numbers; clicking calls `root.switchDesktop(n)`, which picks the right mechanism for the running compositor. On Hyprland each reads `[n,m]` with this screen's m (`root.gridM`)
- **Center.qml** - Clock with 12h arc indicator (blue AM / peach PM); left-click opens WindowMenu (KWin only), middle-click opens PowerMenu
- **Right.qml** - Row of pills: `YtmPill | VolumePill | BatteryPill`

### Pill interactions

| Pill | Left click | Middle click | Right click | Scroll |
|------|-----------|--------------|-------------|--------|
| YtmPill | Toggle YtmPanel | - | - | App volume ±`ytmVolumeStep`% (API `volume-up` / `volume-down`) |
| VolumePill | Open VolumeSlider | Toggle Bluetooth headphones (`volume-toggle-bt.sh`) | Mute toggle | ±1% volume |
| BatteryPill | - | Open PowerProfileMenu | - | - |

### Reusable components (`components/`)

| File | What it is | Used by |
|------|------------|---------|
| `SliderTrack.qml` | "filled \| gap \| handle \| gap \| empty" bar for a `position` 0..1 | VolumeBarSlider |
| `VolumeBarSlider.qml` | slider (default 0..100): SliderTrack background, thin handle, scroll wheel (`onMoved` on drag and scroll) | VolumeSlider (master + apps), YtmPanel seek bar |
| `IconButton.qml` | square button with one Nerd Font icon, active color, state-layer hover / press | YtmPanel controls + side column |
| `ValuePill.qml` | colored pill, value text left, icon right | VolumePill, BatteryPill |
| `PopupCard.qml` | dark rounded card with border, theme colors | VolumeSlider, PowerMenu, PowerProfileMenu, WindowMenu, Clipboard, EditDialogWindow |
| `DialogButton.qml` | flat button with hover color | EditDialogWindow |
| `HoverDebug.qml` | translucent outline of a popup's hover area, shown while `root.debugPopups` | every popup |

### Popups

| File | Opened from | Content |
|------|-------------|---------|
| `VolumeSlider.qml` | VolumePill left click | Master slider + per-app sliders (`wpctl` / `pactl`) |
| `PowerMenu.qml` | Clock middle click | Lock / suspend / reboot / poweroff |
| `PowerProfileMenu.qml` | BatteryPill middle click | performance / balanced / power-saver |
| `WindowMenu.qml` | Clock left click | Open windows grouped by desktop; click focuses, F2 opens `EditDialogWindow.qml` |
| `YtmPanel.qml` | YtmPill left click | Music player: cover, title, artist, seek bar + times, prev / play-pause / next, side column (like, dislike, shuffle, repeat, queue, volume) |
| `Clipboard.qml` | nothing yet (`clipboardOpen` is never set) | WIP clipboard picker: 3 placeholder rows, highlighted row follows `root.clipboardIndex` |

### Scripts (`scripts/`)

Scripts are invoked by QML `Process` objects. They print JSON (or a plain value) to stdout which QML parses via `SplitParser`.

| Script | Usage | Purpose |
|--------|-------|---------|
| `kwin-desktop.py` | no args → print current desktop number; `<n>` → switch | KWin VirtualDesktopManager over DBus (**not used under Hyprland**) |
| `kwin-windows.py` | no args → print JSON window list; `<win_id>` → focus | KWin WindowsRunner + `icons.json` enrichment (Plasma only) |
| `hypr-windows.py` | no args → print JSON window list | `hyprctl clients -j` + `icons.json` enrichment (Hyprland only; currently unused, WindowMenu is off under Hyprland) |
| `window_icons.py` | imported, not run | shared `icons.json` loading, class → icon / display name lookup, blacklist |
| `app-volumes.py` | prints JSON array of `{id, name, volume}` | per-app PulseAudio/PipeWire streams |
| `save-icons-config.py` | `<app_id> <icon> <display_name>` | writes to `icons.json` |
| `add-to-blacklist.py` | `<app_id>` | adds to `icons.json` blacklist |
| `clipboard.py` | long-running, prints `{running, index}` per key press | Reads the keyboard via `evdev`: Up/Down move `index`, Enter prints `running: false` and exits |
| `volume-toggle-bt.sh` | no args | connect/disconnect headphones via `bluetoothctl` |
| `bt-config.sh` | sourced | defines `HEADPHONE_MAC` |

### Music player (YtmPill / YtmPanel)

Source: the YouTube Music Desktop 2 (Venipa `ytmdesktop2`) HTTP API at `root.ytmApiUrl` (`http://127.0.0.1:13091`, enable it in the app's API settings). No helper script: `shell.qml` talks to it with `XMLHttpRequest`.

- Between polls, while playing, `ytmProgressSeconds` moves forward locally every `ytmTickMs` (100 ms); a poll overrides it only when they differ by more than `ytmResyncSeconds` (1.5 s, e.g. after a seek or track change).
- Every `ytmPollMs` (500 ms; `ytmIdlePollMs` 2 s while the app is closed): `GET /track/state` → `{id, playing, progress, duration (s), percentage, liked, disliked, loop}`. When `id` changes: `GET /track` → `video.title`, `video.author`, `video.videoId`.
- Cover art: `root.ytmArt` = `GET /track/thumbnail?id=<videoId>` (served and cached by the app).
- Commands: `root.ytmCommand(cmd, body)` → `POST /track/<cmd>`: `toggle-play-state`, `next`, `prev`, `seek` `{time: <ms>}`, `like` / `dislike` with `true|false`, `shuffle`, `repeat`. After each command the state is re-read.
- Volume is **not** in `/track/state`: `POST /track/volume` with no body only reports `{volume}` (0-100), with `{volume: n}` it sets it. `ytmReadVolume()` / `ytmSetVolume(v)` / `ytmNudgeVolume(up)` (`volume-up` / `volume-down` with `{amount}`) keep `root.ytmVolume` in step, so the pill's scroll wheel and the panel's slider agree.
- Queue: `GET /nav/queue` → `{items: [{index, videoId, title, artist, thumbnail, durationSec}], count}`. `ytmFetchQueue()` finds the current `videoId` and keeps the next `ytmQueueMax` tracks in `root.ytmQueue`. Their `thumbnail` URLs point at Google, so the panel lists the queue as text and never loads them.
- If "require authorization" is on in the app, put the token in `root.ytmApiToken` (sent as `Authorization: Bearer`, and as `?token=` for the cover).

YtmPill is hidden when `ytmAvailable` is false (app closed, API off, or nothing loaded). YtmPanel layout: two cards. The player card (cover / title / artist / seek bar + times / prev, play-pause, next) grows out of the pill: one `morph` value (0 = pill, 1 = player) drives its position, size, corner radius and color from the pill's rectangle to the card centered on the pill, while a copy of the pill crossfades into the content and the real pill hides (`root.ytmPanelScreen`). One ramp (`contentFade`) drives both sides of that crossfade, so their opacities always sum to 1 and the card is never drawn empty. The copy and the real pill live in different windows, so the swap always **overlaps** by `handoffMs`: panel up first then the pill hides, and on the way out the pill returns first then the panel drops. Drawing both for a moment is invisible; drawing neither is a blink. The side card of buttons (like, dislike, shuffle, repeat, queue, volume; list in its Tweakables) sits below the bar, `sideGap` to the right, and grows down with the same `morph`; it is shorter than the player card (`sideHeight`) so both end level at `cardBottom`.

Two overlays, both reset on every open and never shown at once: **queue** flips the cover art over to the upcoming tracks (white text on a dark scrim), and **volume** flips the side card over to a vertical slider (`SliderTrack` with `vertical: true`; drag, click or scroll, and the POST is throttled so a drag is not one request per pixel). There is no close button: leave the hover area or click where the pill is. A blurred copy of the cover art sits behind the card at `artBgStrength`, kept low because the text is the dark `ink`. The pair shifts left if it would leave the screen. The panel window starts at the top of the screen (`ExclusionMode.Ignore`) and uses a `mask` (pill spot + everything below the bar) so the other pills stay clickable. Click where the pill was, or leave the `hoverMargin` (80 px) area, to close. Drag or scroll the seek bar to seek. Cover corners use Quickshell's `ClippingRectangle` (a plain `Rectangle` with `clip: true` does not clip to rounded corners).

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

- `qdbus6` - KWin virtual desktop and window info over DBus (Plasma sessions only)
- Hyprland - read through Quickshell's own `Quickshell.Hyprland` module, no extra tool needed
- `wpctl` - WirePlumber master audio control
- `pactl` - per-app audio stream volumes
- `bluetoothctl` - headphone connect toggle
- `powerprofilesctl` - power profile get/set
- `systemctl` / `loginctl` - power menu actions
- YouTube Music Desktop 2 (`ytmdesktop2`) with its API enabled - music player
- `python-evdev` - keyboard input for `clipboard.py` (needs read access to `/dev/input/event*`)
- `JetBrainsMono Nerd Font` - required for all icons (Nerd Font codepoints used throughout)

QML `Process` commands build script paths from `root.scriptsDir`; never hardcode `/home/...` paths in components.

### Color theme

Catppuccin Mocha, defined once in `shell.qml` → "Theme" (`root.popupBg`, `root.colText`, `root.colBlue`, ...). Pills keep their own status colors in their Tweakables (battery green→red, volume blue/pink/grey, YTM red `#ff4444`). `EditDialogWindow.qml` and `Clipboard.qml` still use their own literal colors.
