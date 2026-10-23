#!/usr/bin/env python3
"""
kwin-windows.py - list open windows for WindowMenu, or focus one.

  kwin-windows.py            -> prints a JSON array of {id, title, app, icon, resourceClass, desktop}
  kwin-windows.py <win_id>   -> focuses that window, called by WindowMenu on click

Windows come from KWin's krunner "WindowsRunner". Each one's resourceClass is looked up in
icons.json to override its icon / display name or hide it (blacklist), through
window_icons.py, which hypr-windows.py shares.
To change how an app shows up, edit icons.json or use F2 in WindowMenu.
"""
import subprocess
import re
import json
import sys

from window_icons import load_icon_config, lookup, pretty_class

# ── Tweakables ──
SKIP_ID_PREFIX = "8_"           # krunner ids starting with this are desktop entries, not windows

icon_mappings, blacklist = load_icon_config()

def get_window_info(uuid):
    try:
        res = subprocess.run(
            ["qdbus6", "org.kde.KWin", "/KWin", "getWindowInfo", uuid],
            capture_output=True, text=True, timeout=1)
        info = {}
        for line in res.stdout.splitlines():
            if ":" in line:
                key, val = line.split(":", 1)
                info[key.strip()] = val.strip()
        return info
    except Exception as e:
        return {}

def get_windows():
    try:
        res = subprocess.run(
            ["qdbus6", "--literal", "org.kde.KWin", "/WindowsRunner", "org.kde.krunner1.Match", ""],
            capture_output=True, text=True, timeout=2)
        raw = res.stdout
    except Exception as e:
        return []

    windows_dict = {}
    
    # Find all window entries - each starts with [Argument: (sssida{sv})
    # Split by this marker to get individual windows
    entries = re.split(r'\[Argument: \(sssida\{sv\}\)', raw)
    
    for entry in entries[1:]:  # Skip the first one (before the first split)
        # Try to extract the first string which is the window ID
        id_match = re.match(r'\s*"([^"]+)"', entry)
        if not id_match:
            continue
            
        win_id = id_match.group(1)
        
        if win_id.startswith(SKIP_ID_PREFIX):  # Skip desktop selectors
            continue
            
        if win_id in windows_dict:
            continue
        
        # Extract: id, title, icon, type, relevance using a simpler approach
        # Pattern: "id", "title", "icon", type_number, relevance, ...
        m = re.match(r'\s*"([^"]+)",\s*"([^"]*)",\s*"([^"]*)",\s*(\d+),\s*([0-9.]+)', entry)
        if not m:
            continue
            
        win_id, win_text, icon, type_id, relevance = m.groups()
        
        # Skip empty titles
        if not win_text.strip():
            continue
        
        # Get more info for App Name
        uuid = win_id.split("_", 1)[-1] if "_" in win_id else win_id
        uuid_clean = uuid.strip("{}")
        info = get_window_info(uuid_clean)
        
        # Extract desktop from subtext field
        desktop = 0
        subtext_match = re.search(r'"subtext"\s*=\s*\[Variant\(QString\):\s*"([^"]*)"', entry)
        if subtext_match:
            subtext = subtext_match.group(1)
            desktop_match = re.search(r'Desktop (\d+)', subtext)
            if desktop_match:
                desktop = int(desktop_match.group(1))
        
        # Fallback: try to get from window info
        if desktop == 0 and "desktops" in info:
            try:
                desktops = info.get("desktops", "").strip()
                if desktops:
                    desktop_list = re.findall(r'\d+', desktops)
                    if desktop_list:
                        desktop = int(desktop_list[0]) + 1
            except:
                pass
        
        # Get app name and clean it up
        app_name = info.get("resourceClass", "").strip()
        if not app_name or app_name.lower() == "wayland":
            app_name = info.get("desktopFile", icon).strip() if icon else ""
            
        # Get icon name - try multiple sources
        icon_name = ""
        
        # First try windowIcon from KWin info
        if info.get("windowIcon", "").strip():
            icon_name = info.get("windowIcon", "").strip()
        
        # Try resourceClass (often org.kde.dolphin, com.github.GitCredentialManager, etc.)
        if not icon_name and app_name:
            icon_name = app_name
        
        # If icon_name has dots, try to extract just the app part or the full name
        if not icon_name and info.get("resourceClass", ""):
            icon_name = info.get("resourceClass", "").strip()
        
        # Final fallback to parsed icon
        if not icon_name and icon and icon != "wayland":
            icon_name = icon
            
        # Clean up app name formatting for display: "org.kde.dolphin" -> "Dolphin"
        display_name = pretty_class(app_name)
        if not display_name:
            display_name = win_text

        # Keys in order of likelihood: app_name (the original class) first, so a config saved
        # under the app's resource class wins
        mapped_icon, mapped_display_name = lookup(icon_mappings, [app_name, icon_name, display_name])

        final_icon = mapped_icon if mapped_icon else icon_name
        final_display_name = mapped_display_name if mapped_display_name else display_name

        # Check if app is blacklisted
        if app_name in blacklist or final_display_name in blacklist:
            continue

        windows_dict[win_id] = {
            "id": win_id,
            "title": win_text,
            "app": final_display_name,
            "icon": final_icon,
            "resourceClass": app_name,
            "desktop": desktop
        }
        
    return list(windows_dict.values())

if __name__ == "__main__":
    if len(sys.argv) > 1:
        win_id = sys.argv[1]
        subprocess.run(["qdbus6", "org.kde.KWin", "/WindowsRunner", "org.kde.krunner1.Run", win_id, ""], timeout=1)
    else:
        print(json.dumps(get_windows()))
