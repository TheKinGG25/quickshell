#!/usr/bin/env python3
"""
window_icons.py - shared icons.json handling for the window-list scripts.

kwin-windows.py and hypr-windows.py both report windows to WindowMenu, keyed by whatever the
compositor calls the window's class. They ask here for the icon and display name to show and
whether the app is hidden. icons.json is edited from the UI with F2 (EditDialogWindow, through
save-icons-config.py / add-to-blacklist.py), so the mapping lives in one place for both.
"""

import json
import os

# ── Tweakables ──
CONFIG_FILE = "icons.json"      # next to this script


def load_icon_config():
    """Returns (iconMappings, blacklist); empty ones if the file is missing or broken."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), CONFIG_FILE)
    try:
        with open(path, "r") as f:
            config = json.load(f)
        return config.get("iconMappings", {}), config.get("blacklist", [])
    except Exception:
        return {}, []


def pretty_class(name):
    """A class as a human name: org.kde.dolphin -> Dolphin, code -> Code."""
    out = (name or "").strip()
    if "." in out:
        out = out.split(".")[-1]        # keep the last part of a reverse-DNS class
    if out and out.islower():
        out = out.capitalize()
    return out


def lookup(mappings, keys):
    """
    First key found in icons.json wins. Returns (icon, display_name), either may be None.
    Accepts both the current {"icon": ..., "displayName": ...} form and the older plain
    "icon name" string form.
    """
    icon = None
    display_name = None
    for key in keys:
        if not key or key not in mappings:
            continue
        mapping = mappings[key]
        if isinstance(mapping, dict):
            if not icon and mapping.get("icon"):
                icon = mapping["icon"]
            if not display_name and mapping.get("displayName"):
                display_name = mapping["displayName"]
        elif isinstance(mapping, str) and not icon:
            icon = mapping
        if icon and display_name:
            break
    return icon, display_name
