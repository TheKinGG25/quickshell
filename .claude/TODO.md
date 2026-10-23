# TODO

Bugs, unfinished features and cleanups for the bar.

**Priority score: 1-10** (10 = do first). The score combines how badly it hurts day-to-day use with how cheap the fix is. **Effort:** S = a few lines, M = one file / an evening, L = new feature or multi-file change.

When something is fixed, delete its row (git history keeps the record). When you find something new, add a row and give it a score.

## Bugs

| Score | Effort | Area | Item | Where |
|------:|:------:|------|------|-------|
| 7 | M | WindowMenu | WindowMenu is KWin-only: `kwin-windows.py` asks `org.kde.KWin` over DBus and returns `[]` under Hyprland, so the menu is empty there (`hyprctl clients` sees the windows). Quickshell's `Hyprland.toplevels` exposes them natively, so branch on `root.hyprland` like `switchDesktop()` does | `scripts/kwin-windows.py`, `WindowMenu.qml` |
| 4 | S | Clipboard | `clipboardProcess` is never started (on purpose until the popup works). Its `onRead` handler uses `root.`, `listView` and `selectEntry()`, none of which exist; `JSON.parse` is not wrapped in `try` | `shell.qml:251-264` |

## Unfinished features

| Score | Effort | Area | Item |
|------:|:------:|------|------|
| 3 | S | Left | On Hyprland, workspaces are created on demand: `Hyprland.workspaces` lists only the ones that exist (e.g. 1, 2, 3), so the fixed `desktopCount` of 6 shows numbers for workspaces that are not there. Could dim the missing ones, or follow the list |
| 4 | M | All popups | Debug mode: one switch in `shell.qml` (e.g. `root.debugPopups`) that draws a translucent outline of each popup's hover area, i.e. where the mouse can be without the popup closing |
| 7 | L | Clipboard | Finish the clipboard popup: open/close via an `activeClipboardScreen` flag + a trigger (pill click or shortcut), feed real history (Klipper over `qdbus6 org.kde.klipper /klipper` or `wl-paste`), copy the chosen entry on Enter |
| 6 | M | Clipboard | Drop the evdev keyboard reader (`clipboard.py`): it needs the `input` group, sees every key typed system-wide and never clamps `index`. The window already takes `WlrKeyboardFocus.Exclusive`, so use QML `Keys.onUpPressed` / `onDownPressed` / `onReturnPressed` |

## Cleanups

| Score | Effort | Item |
|------:|:------:|------|
| - | - | None open. Add new ones here |
