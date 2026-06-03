#!/bin/bash
source ~/.config/quickshell/scripts/bt-config.sh

if bluetoothctl info "$HEADPHONE_MAC" | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$HEADPHONE_MAC"
else
    bluetoothctl connect "$HEADPHONE_MAC"
fi
