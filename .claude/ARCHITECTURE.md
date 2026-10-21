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
| `Bar.qml` | `PanelWindow` (Top layer, anchored top/left/right) | 30px translucent strip holding Left / Center / Right. Publishes `ytmPillLeftX` for YtmPanel placement |
| `Left.qml` | `Row` | `root.desktopCount` desktop numbers, active one white/bold. Click → `kwin-desktop.py <n>` (optimistically sets `currentDesktop`) |
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

### Scripts

| Script | Called by | In → Out |
|--------|-----------|----------|
| `kwin-desktop.py` | `shell.qml` (200ms), `Left.qml` | none → `3`; `<n>` → switches desktop |
| `kwin-windows.py` | `shell.qml` (500ms while WindowMenu open), `WindowMenu.qml` | none → JSON window list enriched from `icons.json`; `<id>` → focus window |
| `app-volumes.py` | `shell.qml` (1s) | → `[{id, name, volume}]` parsed from `pactl list sink-inputs` |
| `ytmd-nowplaying.py` | **you**, manually | CDP websocket to ytmdesktop on port 9222 → `~/.cache/ytmd-now.json` every 1s |
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
| 200ms | `kwin-desktop.py` | `currentDesktop` |
| 500ms | `kwin-windows.py` (only while WindowMenu open) | `windows` |
| 1s | `app-volumes.py` (only while VolumeSlider closed) | `appVolumes` |
| 1s | `powerprofilesctl get` | `powerProfile` |
| 1s | `cat ~/.cache/ytmd-now.json` | `ytm*` |

Paths: every script path is built from `root.scriptsDir` (`Quickshell.env("HOME") + "/.config/quickshell/scripts"`), and the music cache from `root.homeDir`. The 2s timer also restarts `pactl subscribe` if it exits.

Array properties are only reassigned when `JSON.stringify` differs, to avoid needless re-layout of lists.

## 4. Music player pipeline

```
ytmdesktop (Electron, --remote-debugging-port=9222 --remote-allow-origins=*)
   │  Chrome DevTools Protocol: Runtime.evaluate(PAGE_EXPR) once per second
   ▼
scripts/ytmd-nowplaying.py   (separate long-running process, NOT started by quickshell)
   │  reads ytmusic-app.playerApi (title, author, state, time, thumbnails)
   │  + Redux store queue (DOM scrape fallback)
   ▼
~/.cache/ytmd-now.json       { available, playing, state, title, artist, videoId,
   │                           durationSeconds, progressSeconds, art, thumbnails,
   │                           queueSource, queue[] }
   ▼  cat ~/.cache/ytmd-now.json, every 1s (shell.qml ytmProcess)
ShellRoot.ytm*  ──►  YtmPill (bar)  ──click──►  YtmPanel (drop-down)
```

`ytmAvailable` is true only when `available === true` and `title` is non-empty; any parse error sets it to false.

## 5. Known issues and TODO

Bugs, unfinished features and cleanups, with priority scores, are tracked in [`TODO.md`](TODO.md).
