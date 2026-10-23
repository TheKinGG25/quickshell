# Architecture

A QuickShell (QML) top bar for KDE Plasma on Wayland. No build step: `quickshell` interprets the QML at launch and shells out to small Python/Bash helpers for system data.

## 1. Big picture

```
                    ┌───────────────────────────── shell.qml (ShellRoot) ─────────────────────────────┐
                    │  global state properties     pactl events + timers (200ms/500ms/1s/2s)          │
 system tools  ───► │  Process + SplitParser  ───► currentDesktop, volume*, battery*, powerProfile,  │
 (qdbus6, wpctl,    │                              appVolumes[], windows[], ytm*                      │
  pactl, cat ...)   │  popup flags: active{Volume,Power,PowerProfile,Window,Ytm}Screen               │
                    └──────────────┬──────────────────────────────────────────────────────────────────┘
                                   │ root: shellRoot   (passed to every component)
          Variants { model: Quickshell.screens } → one copy of each window per monitor
                                   │
   ┌──────────────┬──────────────┬─┴────────────┬────────────────┬──────────────────┬─────────────┐
   Bar         VolumeSlider   PowerMenu     WindowMenu     PowerProfileMenu      YtmPanel     Clipboard
   │                                            └─ EditDialogWindow
   ├─ Left    (desktops 1-6)
   ├─ Center  (clock + arc)
   └─ Right   (YtmPill | VolumePill | BatteryPill)
```

Rules the code follows:

1. **One source of truth.** All shared state lives on `ShellRoot`. Components only read it and write the `active*Screen` flags.
2. **Pull, not push.** Every value is polled: a `Timer` sets `process.running = true`, the process prints to stdout, a `SplitParser.onRead` parses it and assigns a property. QML bindings do the rest.
3. **Per-screen windows, global flags.** Each window exists on every screen and shows itself only when `root.activeXScreen === screen`. That way a popup opens on the monitor whose bar was clicked.
4. **Side effects go through `Process`.** Clicks build a command array (e.g. `wpctl set-mute ...`, `kwin-desktop.py 3`) and start a `Process` owned by the component.

## 2. Files

### QML

| File | Kind | Responsibility |
|------|------|----------------|
| `shell.qml` | `ShellRoot` | Global state, all polling processes and timers, instantiates every window per screen |
| `Bar.qml` | `PanelWindow` (Top layer, anchored top/left/right) | 30px translucent strip holding Left / Center / Right. Publishes its own screen's YtmPill position (`setYtmPillGeom`) for YtmPanel placement |
| `Left.qml` | `Row` | `root.desktopCount` desktop / workspace numbers, active one white/bold, nonexistent Hyprland workspaces dimmed. Click → `root.switchDesktop(n)`, which branches on the compositor (optimistically sets `currentDesktop`) |
| `Center.qml` | `MouseArea` | Canvas arc showing progress through the 12h half-day (blue AM, peach PM) + `hh:mm:ss AP \| dddd - dd/MM/yy`. Left click → WindowMenu, middle → PowerMenu |
| `Right.qml` | `Row` | `YtmPill`, `VolumePill`, `BatteryPill` |
| `YtmPill.qml` | `Rectangle` 280x22 | Thumbnail, title, artist, 2px progress line. Hidden unless `ytmAvailable`. Click toggles YtmPanel |
| `YtmPanel.qml` | `PanelWindow` (Overlay) | Drop-down card under the pill: 180px art, title, artist, `m:ss` labels, progress bar. Height animates 0 → 290 on open. Click anywhere closes |
| `VolumePill.qml` | `Rectangle` | Volume number + icon. Color: grey muted / pink bluetooth / blue speakers. Left: slider, middle: BT toggle, right: mute, wheel: ±1% |
| `VolumeSlider.qml` | `PanelWindow` (Overlay, top-right) | Master slider (`wpctl`) and one slider per app stream (`pactl`) |
| `BatteryPill.qml` | `Rectangle` | Percent + arrow (↑ charging, ↓ discharging, - plugged but not charging). Color steps every 20%. Middle click → PowerProfileMenu |
| `PowerProfileMenu.qml` | `PanelWindow` (Overlay, top-right) | One row per entry in its `profiles` list, click runs `powerprofilesctl set <profile>` |
| `PowerMenu.qml` | `PanelWindow` (Overlay, centered) | One button per entry in its `buttons` list (icon, label, color, command): shutdown / restart / sleep / lock |
| `WindowMenu.qml` | `PanelWindow` (Overlay, centered, keyboard OnDemand) | Desktop tabs (`root.desktopCount`) + list of windows on the selected desktop. Click focuses via `kwin-windows.py <id>`. F2 on hover opens EditDialogWindow. Closes 200ms after mouse leaves unless the dialog is open |
| `Clipboard.qml` | `PanelWindow` (top-right, keyboard Exclusive) | WIP clipboard picker. Shows 3 placeholder rows ("Copied Item n"), the row at `root.clipboardIndex` is highlighted. Visible only when its own `clipboardOpen` is true, which nothing sets yet |
| `EditDialogWindow.qml` | `Window` | Edit icon + display name for a `resourceClass`, or blacklist it. Writes through `save-icons-config.py` / `add-to-blacklist.py` |

### Components (`components/`)

Shared building blocks, imported with `import "components"`.

| File | What it is | Used by |
|------|------------|---------|
| `SliderTrack.qml` | "filled \| gap \| handle \| gap \| empty" bar for a `position` 0..1 | VolumeBarSlider, YtmPanel progress |
| `VolumeBarSlider.qml` | 0..100 slider: SliderTrack background, thin handle, scroll wheel (`onMoved` on drag and scroll) | VolumeSlider (master + apps) |
| `ValuePill.qml` | colored pill, value text left, icon right | VolumePill, BatteryPill |
| `PopupCard.qml` | dark rounded card with border, theme colors | VolumeSlider, PowerMenu, PowerProfileMenu, WindowMenu, Clipboard, EditDialogWindow |
| `DialogButton.qml` | flat button with hover color | EditDialogWindow |

### Scripts

| Script | Called by | In → Out |
|--------|-----------|----------|
| `kwin-desktop.py` | `shell.qml` (200ms, KWin only), `switchDesktop()` | none → `3`; `<n>` → switches desktop |
| `kwin-windows.py` | `shell.qml` (500ms while WindowMenu open, KWin only), `focusWindow()` | none → JSON window list enriched from `icons.json`; `<id>` → focus window |
| `hypr-windows.py` | `shell.qml` (500ms while WindowMenu open, Hyprland only) | `hyprctl clients -j` → the same JSON window list |
| `window_icons.py` | imported by both window scripts | shared `icons.json` lookup and blacklist |
| `app-volumes.py` | `shell.qml` (1s) | → `[{id, name, volume}]` parsed from `pactl list sink-inputs` |
| `save-icons-config.py` | `Clipboard.qml` | `PanelWindow` (top-right, keyboard Exclusive) | WIP clipboard picker. Shows 3 placeholder rows ("Copied Item n"), the row at `root.clipboardIndex` is highlighted. Visible only when its own `clipboardOpen` is true, which nothing sets yet |
| `EditDialogWindow.qml` | `<app_id> <icon> <name>` → updates `icons.json` |
| `add-to-blacklist.py` | `Clipboard.qml` | `PanelWindow` (top-right, keyboard Exclusive) | WIP clipboard picker. Shows 3 placeholder rows ("Copied Item n"), the row at `root.clipboardIndex` is highlighted. Visible only when its own `clipboardOpen` is true, which nothing sets yet |
| `EditDialogWindow.qml` | `<app_id>` → appends to blacklist |
| `clipboard.py` | `shell.qml` `clipboardProcess` (never started yet) | Reads the first keyboard via `evdev`; prints `{running, index}` on Up/Down, prints `running: false` and exits on Enter |
| `volume-toggle-bt.sh` + `bt-config.sh` | `VolumePill.qml` | connect/disconnect `HEADPHONE_MAC` |
| `icons.json` | `kwin-windows.py` | `iconMappings` keyed by `resourceClass`, plus `blacklist` |

## 3. Polling schedule

| Every | Process | Property |
|-------|---------|----------|
| event | `pactl subscribe` (long-running). A `sink` or `server` event restarts a 30ms debounce timer that runs the two reads below | |
| event + 2s | `wpctl get-volume @DEFAULT_AUDIO_SINK@` | `volumeLevel`, `volumeMuted` |
| event + 2s | `wpctl inspect ... \| grep -c api.bluez5.address` | `headphonesActive` |
| 2s | `sh -c` loop over `/sys/class/power_supply/BAT*`, first match: `capacity` then `status` | `batteryLevel`, `batteryStatus` |
| 200ms | `kwin-desktop.py` (KWin only; under Hyprland the timer is off and `Hyprland.focusedWorkspace` drives `currentDesktop`) | `currentDesktop` |
| 500ms | `kwin-windows.py` (only while WindowMenu open) | `windows` |
| 1s | `app-volumes.py` (only while VolumeSlider closed) | `appVolumes` |
| 1s | `powerprofilesctl get` | `powerProfile` |
| 500ms (2s idle) | `GET /track/state` (+ `GET /track` on change) on the music API | `ytm*` |

Paths: every script path is built from `root.scriptsDir` (`Quickshell.env("HOME") + "/.config/quickshell/scripts"`), and the music cache from `root.homeDir`. The 2s timer also restarts `pactl subscribe` if it exits.

Array properties are only reassigned when `JSON.stringify` differs, to avoid needless re-layout of lists.

## 4. Music player pipeline

```
YouTube Music Desktop 2 (ytmdesktop2), API on http://127.0.0.1:13091
   ▲  POST /track/<cmd>  (toggle-play-state, next, prev, seek, like, dislike, shuffle, repeat)
   │        ▲ root.ytmCommand(cmd, body)  ◄── YtmPanel buttons / seek bar
   │
   ▼  GET /track/state every 500ms (2s while unreachable), GET /track when the track id changes
shell.qml ytmPoll()  (XMLHttpRequest, no helper script)
   ▼
ShellRoot.ytm*  ──►  YtmPill (bar)  ──click──►  YtmPanel (player card)
                      cover: GET /track/thumbnail?id=<videoId>
```

`ytmAvailable` is false when the API does not answer, `/track/state` is null, or the track has no title.

## 5. Known issues and TODO

Bugs, unfinished features and cleanups, with priority scores, are tracked in [`TODO.md`](TODO.md).
