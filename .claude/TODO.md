# TODO

Bugs, unfinished features and cleanups for the bar.

**Priority score: 1-10** (10 = do first). The score combines how badly it hurts day-to-day use with how cheap the fix is. **Effort:** S = a few lines, M = one file / an evening, L = new feature or multi-file change.

When something is fixed, delete its row (git history keeps the record). When you find something new, add a row and give it a score.

## Bugs

| Score | Effort | Area | Item | Where |
|------:|:------:|------|------|-------|
| 7 | S | Music | Cover art corners are not rounded: `clip: true` on a Rectangle clips to its square bounds and ignores `radius`. Use Quickshell's `ClippingRectangle` (`Quickshell.Widgets`) or a `MultiEffect` mask | `YtmPanel.qml:155` |
| 6 | S | Music | Player card starts `topGap` (4px) below the bar instead of right at its bottom edge. Set the gap to 0 (and check the bar's exclusive zone puts it exactly there) | `YtmPanel.qml:24,67` |
| 6 | S | Music | Fade-out (hover) area is only the card itself, so the player closes as soon as the mouse slips off. Make the window bigger than the card with an invisible margin, like VolumeSlider (+60 / +80) | `YtmPanel.qml:70-71,113` |
| 5 | M | Music | `ytmPillLeftX` is one global value written by every screen's Bar, so YtmPanel is misplaced on multi-monitor setups with different widths. Store it per screen or compute it inside YtmPanel | `Bar.qml:53`, `YtmPanel.qml:69` |
| 4 | S | Clipboard | `clipboardProcess` is never started (on purpose until the popup works). Its `onRead` handler uses `root.`, `listView` and `selectEntry()`, none of which exist; `JSON.parse` is not wrapped in `try` | `shell.qml:251-264` |

## Unfinished features

| Score | Effort | Area | Item |
|------:|:------:|------|------|
| 6 | M | Music | Replace the bottom side button (close) with a volume button: it opens a vertical slider and sets the app's volume through the API (`POST /track/volume {volume}`, returns `{volume}`; `/track/state` has no volume, so read the current value from that response or `volume-up` / `volume-down`). Can reuse `VolumeBarSlider` with `orientation: Qt.Vertical` |
| 5 | M | Music | Use the song's cover art as the card background (cover scaled to fill, blurred and darkened with `MultiEffect` so the text stays readable) |
| 4 | M | All popups | Debug mode: one switch in `shell.qml` (e.g. `root.debugPopups`) that draws a translucent outline of each popup's hover area, i.e. where the mouse can be without the popup closing |
| 7 | L | Clipboard | Finish the clipboard popup: open/close via an `activeClipboardScreen` flag + a trigger (pill click or shortcut), feed real history (Klipper over `qdbus6 org.kde.klipper /klipper` or `wl-paste`), copy the chosen entry on Enter |
| 6 | M | Clipboard | Drop the evdev keyboard reader (`clipboard.py`): it needs the `input` group, sees every key typed system-wide and never clamps `index`. The window already takes `WlrKeyboardFocus.Exclusive`, so use QML `Keys.onUpPressed` / `onDownPressed` / `onReturnPressed` |
| 3 | M | Music | Show the upcoming queue in YtmPanel (`GET /nav/queue` on the API) |
| 2 | S | Music | Scroll on YtmPill to change the YouTube Music app volume (`POST /track/volume-up` / `volume-down`), matching VolumePill |
| 3 | S | Music | YtmPanel has an open animation but no close animation |
| 2 | S | Music | Progress only moves every 500ms (one poll); could interpolate locally between polls while playing |

## Cleanups

| Score | Effort | Item |
|------:|:------:|------|
| 5 | M | Music player colors: replace the per-item color variables in YtmPanel (`buttonColor`, `playColor`, `seekFill`, `titleColor`, ...) with a few role colors using the usual naming: `primary` / `onPrimary`, `secondary` / `onSecondary`, `surface` / `onSurface`, `surfaceVariant`, `outline`. Items pick a role. Later the same roles could replace the theme in `shell.qml` |
