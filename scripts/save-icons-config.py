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
        
        # Update the mapping
        config["iconMappings"][app_id] = icon
        
        # Save the config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(json.dumps({"success": True, "message": "Icon configuration saved"}))
        return 0
    except Exception as e:
        print(json.dumps({"success": False, "message": str(e)}))
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(json.dumps({"success": False, "message": "Usage: save-icons-config.py <app_id> <icon>"}))
        sys.exit(1)
    
    app_id = sys.argv[1]
    icon = sys.argv[2]
    
    sys.exit(save_icon_config(app_id, icon, None))
