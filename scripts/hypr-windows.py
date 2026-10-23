#!/usr/bin/env python3
"""
hypr-windows.py - list open windows for WindowMenu under Hyprland.

  hypr-windows.py   -> JSON array of {id, title, app, icon, resourceClass, desktop}

Same shape as kwin-windows.py, so WindowMenu does not care which compositor is running;
shell.qml picks the script (root.windowsScript). `id` is the Hyprland window address, and
focusing is done in QML by shell.qml's focusWindow(), because the dispatch syntax depends on
whether Hyprland runs a Lua config.

Icons, display names and the blacklist come from icons.json through window_icons.py.
"""

import json
import subprocess

from window_icons import load_icon_config, lookup, pretty_class


def get_windows():
    try:
        raw = subprocess.run(["hyprctl", "clients", "-j"],
                             capture_output=True, text=True, timeout=2).stdout
        clients = json.loads(raw)
    except Exception:
        return []

    icon_mappings, blacklist = load_icon_config()
    windows = []

    for client in clients:
        title = (client.get("title") or "").strip()
        if not title:
            continue        # windows with no title are not worth listing

        resource_class = (client.get("class") or client.get("initialClass") or "").strip()
        display_name = pretty_class(resource_class)
        icon, mapped_name = lookup(icon_mappings,
                                   [resource_class, client.get("initialClass"), display_name])
        final_name = mapped_name or display_name or title

        if resource_class in blacklist or final_name in blacklist:
            continue

        workspace = client.get("workspace") or {}
        windows.append({
            "id": client.get("address", ""),
            "title": title,
            "app": final_name,
            "icon": icon or resource_class,
            "resourceClass": resource_class,
            "desktop": int(workspace.get("id") or 0),
        })

    return windows


if __name__ == "__main__":
    print(json.dumps(get_windows()))
