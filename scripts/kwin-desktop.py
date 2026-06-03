#!/usr/bin/env python3
import subprocess
import re
import sys

def get_desktops():
    try:
        raw = subprocess.run(
            ["qdbus6", "--literal", "org.kde.KWin", "/VirtualDesktopManager", "desktops"],
            capture_output=True, text=True, timeout=1).stdout
        return re.findall(r'\(uss\)\s+(\d+),\s+"([^"]+)"', raw)
    except:
        return []

def get_current_uuid():
    try:
        return subprocess.run(
            ["qdbus6", "org.kde.KWin", "/VirtualDesktopManager", "current"],
            capture_output=True, text=True, timeout=1).stdout.strip()
    except:
        return ""

if len(sys.argv) > 1:
    target_idx = int(sys.argv[1]) - 1
    desktops = get_desktops()
    for idx, uuid in desktops:
        if int(idx) == target_idx:
            subprocess.run(["qdbus6", "org.kde.KWin", "/VirtualDesktopManager", "current", uuid], timeout=1)
            break
else:
    current_uuid = get_current_uuid()
    desktops = get_desktops()
    for idx, uuid in desktops:
        if uuid == current_uuid:
            print(int(idx) + 1)
            sys.exit(0)
    # If not found, maybe it's already an index?
    if current_uuid.isdigit():
        print(int(current_uuid) + 1)
    else:
        print(1)
