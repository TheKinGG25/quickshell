#!/usr/bin/env python3
"""
app-volumes.py - per-app audio streams for the VolumeSlider popup.

Prints a JSON array of {id, name, volume} parsed from `pactl list sink-inputs`.
`id` is the sink-input number used by `pactl set-sink-input-volume` in VolumeSlider.qml.
Name comes from application.name, falling back to media.name.
"""
import subprocess
import json
import re

def get_app_volumes():
    try:
        # Get sink inputs (streams) from pactl as it provides cleaner JSON/structured data for apps
        result = subprocess.run(["pactl", "list", "sink-inputs"], capture_output=True, text=True)
        sections = result.stdout.split("Sink Input #")
        apps = []
        
        for section in sections[1:]:
            # Extract ID
            id_match = re.search(r"^(\d+)", section)
            if not id_match: continue
            stream_id = id_match.group(1)
            
            # Extract Name
            name_match = re.search(r"application.name = \"([^\"]+)\"", section)
            # Fallback to media.name
            if not name_match:
                name_match = re.search(r"media.name = \"([^\"]+)\"", section)
            
            name = name_match.group(1) if name_match else f"Stream {stream_id}"
            
            # Extract Volume
            vol_match = re.search(r"Volume:.*?(\d+)%", section)
            volume = int(vol_match.group(1)) if vol_match else 0
            
            apps.append({"id": stream_id, "name": name, "volume": volume})
            
        print(json.dumps(apps))
    except Exception as e:
        print("[]")

if __name__ == "__main__":
    get_app_volumes()
