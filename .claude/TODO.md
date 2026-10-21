# TODO

Bugs, unfinished features and cleanups for the bar.

**Priority score: 1-10** (10 = do first). The score combines how badly it hurts day-to-day use with how cheap the fix is. **Effort:** S = a few lines, M = one file / an evening, L = new feature or multi-file change.

When something is fixed, delete its row (git history keeps the record). When you find something new, add a row and give it a score.

## Bugs

| Score | Effort | Area | Item | Where |
|------:|:------:|------|------|-------|
| 5 | M | Music | `ytmPillLeftX` / `ytmPillTopY` are global values written by every screen's Bar, so YtmPanel is misplaced on multi-monitor setups with different widths. Store it per screen or compute it inside YtmPanel | `Bar.qml:53`, `YtmPanel.qml` `cardScreenX` |
| 4 | S | Clipboard | `clipboardProcess` is never started (on purpose until the popup works). Its `onRead` handler uses `root.`, `listView` and `selectEntry()`, none of which exist; `JSON.parse` is not wrapped in `try` | `shell.qml:251-264` |

## Unfinished features

| Score | Effort | Area | Item |
|------:|:------:|------|------|
| 6 | M | Music | Replace the bottom side button (close) with a volume button: it opens a vertical slider and sets the app's volume through the API (`POST /track/volume {volume}`, returns `{volume}`; `/track/state` has no volume, but `POST /track/volume` with no body just returns the current `{volume}`). Can reuse `VolumeBarSlider` with `orientation: Qt.Vertical` |
| 5 | M | Music | Use the song's cover art as the card background (cover scaled to fill, blurred and darkened with `MultiEffect` so the text stays readable) |
| 4 | M | All popups | Debug mode: one switch in `shell.qml` (e.g. `root.debugPopups`) that draws a translucent outline of each popup's hover area, i.e. where the mouse can be without the popup closing |
| 7 | L | Clipboard | Finish the clipboard popup: open/close via an `activeClipboardScreen` flag + a trigger (pill click or shortcut), feed real history (Klipper over `qdbus6 org.kde.klipper /klipper` or `wl-paste`), copy the chosen entry on Enter |
| 6 | M | Clipboard | Drop the evdev keyboard reader (`clipboard.py`): it needs the `input` group, sees every key typed system-wide and never clamps `index`. The window already takes `WlrKeyboardFocus.Exclusive`, so use QML `Keys.onUpPressed` / `onDownPressed` / `onReturnPressed` |
| 3 | M | Music | Show the upcoming queue in YtmPanel (`GET /nav/queue` on the API) |

## Cleanups

| Score | Effort | Item |
|------:|:------:|------|
| - | - | None open. Add new ones here |
