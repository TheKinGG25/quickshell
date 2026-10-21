#!/bin/bash
# volume-toggle-bt.sh - connect the headphones if disconnected, disconnect if connected.
# Called by middle-clicking VolumePill. The headphone MAC lives in bt-config.sh.
source "$(dirname "$0")/bt-config.sh"

if bluetoothctl info "$HEADPHONE_MAC" | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$HEADPHONE_MAC"
else
    bluetoothctl connect "$HEADPHONE_MAC"
fi
