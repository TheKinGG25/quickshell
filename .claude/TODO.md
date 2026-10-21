# TODO

Bugs, unfinished features and cleanups for the bar.

**Priority score: 1-10** (10 = do first). The score combines how badly it hurts day-to-day use with how cheap the fix is. **Effort:** S = a few lines, M = one file / an evening, L = new feature or multi-file change.

When something is fixed, delete its row (git history keeps the record). When you find something new, add a row and give it a score.

## Bugs

| Score | Effort | Area | Item | Where |
|------:|:------:|------|------|-------|
| 5 | M | Music | `ytmPillLeftX` is one global value written by every screen's Bar, so YtmPanel is misplaced on multi-monitor setups with different widths. Store it per screen or compute it inside YtmPanel | `Bar.qml:53`, `YtmPanel.qml:69` |
| 4 | S | Clipboard | `clipboardProcess` is never started (on purpose until the popup works). Its `onRead` handler uses `root.`, `listView` and `selectEntry()`, none of which exist; `JSON.parse` is not wrapped in `try` | `shell.qml:251-264` |

## Unfinished features

| Score | Effort | Area | Item |
|------:|:------:|------|------|
| 7 | L | Clipboard | Finish the clipboard popup: open/close via an `activeClipboardScreen` flag + a trigger (pill click or shortcut), feed real history (Klipper over `qdbus6 org.kde.klipper /klipper` or `wl-paste`), copy the chosen entry on Enter |
| 6 | M | Clipboard | Drop the evdev keyboard reader (`clipboard.py`): it needs the `input` group, sees every key typed system-wide and never clamps `index`. The window already takes `WlrKeyboardFocus.Exclusive`, so use QML `Keys.onUpPressed` / `onDownPressed` / `onReturnPressed` |
| 3 | M | Music | Show the upcoming queue in YtmPanel (`GET /nav/queue` on the API) |
| 2 | S | Music | Scroll on YtmPill to change the YouTube Music app volume (`POST /track/volume-up` / `volume-down`), matching VolumePill |
| 3 | S | Music | YtmPanel has an open animation but no close animation |
| 2 | S | Music | Progress only moves every 500ms (one poll); could interpolate locally between polls while playing |

## Cleanups

| Score | Effort | Item |
|------:|:------:|------|
| - | - | None open. Add new ones here |
