# TODO

Bugs, unfinished features and cleanups for the bar.

**Priority score: 1-10** (10 = do first). The score combines how badly it hurts day-to-day use with how cheap the fix is. **Effort:** S = a few lines, M = one file / an evening, L = new feature or multi-file change.

When something is fixed, delete its row (git history keeps the record). When you find something new, add a row and give it a score.

## Bugs

| Score | Effort | Area | Item | Where |
|------:|:------:|------|------|-------|
| 9 | S | Shell | Polling paths are relative to the working directory (`.config/quickshell/scripts/...`, `.cache/ytmd-now.json`). Launching from anywhere but `$HOME` breaks desktop, volume app list, windows and music. Use absolute paths or `Quickshell.shellDir` / `Quickshell.env("HOME")` | `shell.qml:57,85,100,151,186` |
| 8 | S | Power profile | Typo `root.fontFamlily`, so the profile icons lose the Nerd Font and probably render as boxes | `PowerProfileMenu.qml:105` |
| 7 | S | Clipboard | `Component.onCompleted` runs `clipboardProcess = false`: the id is actually `clipboardProcss` (typo) and the line assigns instead of setting `.running`. Throws on startup | `shell.qml:185,245` |
| 6 | S | Music | Pill freezes on the last track when `ytmd-nowplaying.py` dies, because the cache file keeps its last contents. Add a timestamp to the JSON and treat it as unavailable when older than ~3s | `scripts/ytmd-nowplaying.py`, `shell.qml` ytmProcess |
| 6 | S | Music | Pill can flicker: the script truncates and rewrites the file in place, so `cat` can read half a file, `JSON.parse` fails and the pill hides for a tick. Write to a temp file and `os.replace` | `scripts/ytmd-nowplaying.py:218` |
| 5 | S | Shell | `running: root.activeWindowScreen !== null`: there is no `root` id in `shell.qml` (it is `shellRoot`), so the binding errors. The 1s timer hides it | `shell.qml:48` |
| 5 | S | Bar | `barWindow.root.screen.width` does not exist on `ShellRoot`, throws on every x change. `rightLength` is unused, so the line can just go | `Bar.qml:44` |
| 5 | M | Music | `ytmPillLeftX` is one global value written by every screen's Bar, so YtmPanel is misplaced on multi-monitor setups with different widths. Store it per screen or compute it inside YtmPanel | `Bar.qml:43`, `YtmPanel.qml:14` |
| 4 | S | Clipboard | `onRead` handler uses `root.`, `listView` and `selectEntry()`, none of which exist; `JSON.parse` is not wrapped in `try` | `shell.qml:187-198` |
| 3 | S | Clipboard | `focusedIndex` and bare `fontSize` are undefined inside `Clipboard.qml` | `Clipboard.qml:49,68` |

## Unfinished features

| Score | Effort | Area | Item |
|------:|:------:|------|------|
| 7 | M | Music | YtmPanel polish ("junky"): replace the negative top margin trick, add a close animation, close on mouse exit like the other popups, shrink the always-290px transparent click-catching area, use one color scheme (red card vs Catppuccin progress bar) |
| 7 | L | Clipboard | Finish the clipboard popup: open/close via an `activeClipboardScreen` flag + a trigger (pill click or shortcut), feed real history (Klipper over `qdbus6 org.kde.klipper /klipper` or `wl-paste`), copy the chosen entry on Enter |
| 6 | M | Clipboard | Drop the evdev keyboard reader (`clipboard.py`): it needs the `input` group, sees every key typed system-wide and never clamps `index`. The window already takes `WlrKeyboardFocus.Exclusive`, so use QML `Keys.onUpPressed` / `onDownPressed` / `onReturnPressed` |
| 6 | M | Music | Playback controls (play/pause, next, previous, seek by clicking the progress bar). The script can call `playerApi` through the same CDP connection; needs a small command channel (e.g. a FIFO or a second one-shot script) |
| 5 | S | Music | Start the feed automatically: launch `ytmd-nowplaying.py` from `shell.qml` as a long-running `Process` (or a systemd user unit) instead of by hand |
| 4 | S | Music | Show the playing/paused state (`ytmPlaying` is parsed but unused), e.g. dim the pill or show a pause icon |
| 3 | M | Music | Show the upcoming queue in YtmPanel (`queue[]` is already in the JSON) |
| 2 | S | Music | Scroll on YtmPill to change the YouTube Music app volume, matching VolumePill |

## Cleanups

| Score | Effort | Item |
|------:|:------:|------|
| 4 | S | Replace hardcoded `/home/thekingg/.config/quickshell/...` paths in components (`Left.qml`, `VolumePill.qml`, `WindowMenu.qml`, `EditDialogWindow.qml`) with one root property, e.g. `root.scriptsDir` |
| 3 | M | 100ms polling of volume, bluetooth sink and battery spawns 4 processes 10 times a second. Battery can poll every few seconds; volume could use `pactl subscribe` as a long-running `Process` |
| 2 | S | Battery path hardcoded to `BAT0`; use `UPower` from Quickshell or detect the battery name |
| 1 | S | Typos in ids and names: `clipboardProcss`, `fontFamlily`, mixed tabs/spaces in `VolumePill.qml`, `BatteryPill.qml`, `Clipboard.qml` |
