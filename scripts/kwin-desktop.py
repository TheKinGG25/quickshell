#!/usr/bin/env python3
import subprocess, re

current = subprocess.run(
    ["qdbus6", "org.kde.KWin", "/VirtualDesktopManager", "current"],
    capture_output=True, text=True).stdout.strip()

raw = subprocess.run(
    ["qdbus6", "--literal", "org.kde.KWin", "/VirtualDesktopManager", "desktops"],
    capture_output=True, text=True).stdout

desktops = re.findall(r'\(uss\)\s+(\d+),\s+"([^"]+)"', raw)
idx = next((int(p) + 1 for p, u in desktops if u == current), 1)
print(idx)
