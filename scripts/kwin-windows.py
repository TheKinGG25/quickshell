#!/usr/bin/env python3
import subprocess
import re
import json
import sys

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
    except:
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
    
    # Split by the entry prefix
    entries = raw.split("[Argument: (sssida{sv})")
    for entry in entries[1:]:
        # Parse fields: "id", "text", "icon", type, relevance, [Argument: a{sv} {props}]
        # Simplified regex for each entry
        m = re.search(r'^ "([^"]+)", "([^"]+)", "([^"]*)", (\d+), ([0-9.]+), \[Argument: a\{sv\} \{(.*)\}\]', entry.strip())
        if not m:
            continue
            
        win_id, win_text, icon, type_id, relevance, props = m.groups()
        
        if win_id.startswith("8_"): # Skip desktop selectors
            continue
            
        if win_id in windows_dict:
            continue
            
        # Match desktop
        desktop = 0
        desktop_match = re.search(r'Activate running window on Desktop (\d+)', props)
        if desktop_match:
            desktop = int(desktop_match.group(1))
        
        # Get more info for App Name
        uuid = win_id.split("_", 1)[-1] if "_" in win_id else win_id
        # Remove curly braces if present
        uuid_clean = uuid.strip("{}")
        info = get_window_info(uuid)
        
        app_name = info.get("resourceClass", "")
        if not app_name or app_name.lower() == "wayland":
            app_name = info.get("desktopFile", icon)
            
        if app_name and app_name.islower():
            app_name = app_name.capitalize()

        windows_dict[win_id] = {
            "id": win_id,
            "title": win_text,
            "app": app_name if app_name else win_text,
            "icon": icon if icon else "wayland",
            "desktop": desktop
        }
        
    return list(windows_dict.values())

if __name__ == "__main__":
    if len(sys.argv) > 1:
        win_id = sys.argv[1]
        subprocess.run(["qdbus6", "org.kde.KWin", "/WindowsRunner", "org.kde.krunner1.Run", win_id, ""], timeout=1)
    else:
        print(json.dumps(get_windows()))
