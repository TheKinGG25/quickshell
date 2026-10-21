#!/usr/bin/env python3
"""
add-to-blacklist.py - hide an app from WindowMenu by adding it to the icons.json blacklist.

  add-to-blacklist.py <app_id>

Called by the "Blacklist" button in EditDialogWindow.qml. To un-hide, remove the entry from
"blacklist" in icons.json by hand.
"""
import json
import sys
import os

# ── Tweakables ──
CONFIG_FILE = "icons.json"      # next to this script

def add_to_blacklist(app_id):
    """Add an app to the blacklist"""
    config_path = os.path.join(os.path.dirname(__file__), CONFIG_FILE)
    
    try:
        # Load existing config
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                config = json.load(f)
        else:
            config = {"iconMappings": {}, "blacklist": []}
        
        # Ensure blacklist exists
        if "blacklist" not in config:
            config["blacklist"] = []
        
        # Add to blacklist if not already there
        if app_id not in config["blacklist"]:
            config["blacklist"].append(app_id)
        
        # Save the config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(json.dumps({"success": True, "message": f"Added {app_id} to blacklist"}))
        return 0
    except Exception as e:
        print(json.dumps({"success": False, "message": str(e)}))
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "message": "Usage: add-to-blacklist.py <app_id>"}))
        sys.exit(1)
    
    app_id = sys.argv[1]
    sys.exit(add_to_blacklist(app_id))
