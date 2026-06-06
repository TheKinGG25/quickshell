#!/usr/bin/env python3
import json
import sys
import os

def save_icon_config(app_id, icon, display_name):
    """Save or update icon configuration"""
    config_path = os.path.join(os.path.dirname(__file__), "icons.json")
    
    try:
        # Load existing config
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                config = json.load(f)
        else:
            config = {"iconMappings": {}}
        
        # Ensure iconMappings exists
        if "iconMappings" not in config:
            config["iconMappings"] = {}
        
        # Initialize app entry if it doesn't exist or ensure it's a dict
        if app_id not in config["iconMappings"] or not isinstance(config["iconMappings"][app_id], dict):
            config["iconMappings"][app_id] = {}
        
        # Update the mapping with both icon and display name
        if icon and icon.strip():
            config["iconMappings"][app_id]["icon"] = icon.strip()
        if display_name and display_name.strip():
            config["iconMappings"][app_id]["displayName"] = display_name.strip()
        
        # Save the config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        # Debug output
        with open("/tmp/save-icons-debug.log", "a") as log:
            log.write(f"Saved: app_id={app_id}, icon={icon}, display_name={display_name}\n")
            log.write(f"Config: {json.dumps(config['iconMappings'].get(app_id, {}))}\n")
        
        print(json.dumps({"success": True, "message": "Configuration saved"}))
        return 0
    except Exception as e:
        with open("/tmp/save-icons-debug.log", "a") as log:
            log.write(f"Error: {str(e)}\n")
        print(json.dumps({"success": False, "message": str(e)}))
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "message": "Usage: save-icons-config.py <app_id> [icon] [display_name]"}))
        sys.exit(1)
    
    app_id = sys.argv[1]
    icon = sys.argv[2] if len(sys.argv) > 2 else ""
    display_name = sys.argv[3] if len(sys.argv) > 3 else ""
    
    sys.exit(save_icon_config(app_id, icon, display_name))

