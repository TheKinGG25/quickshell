#!/usr/bin/env python3
"""
clipboard.py - keyboard reader for the clipboard popup (WORK IN PROGRESS, see .claude/TODO.md).

Reads the first keyboard via evdev (needs read access to /dev/input, i.e. the `input` group).
Prints {"running": true, "index": n} on every Up / Down, then {"running": false, ...} on Enter and exits.
"""
import sys, json
from evdev import InputDevice, categorize, ecodes, list_devices

def find_keyboard():
    for path in list_devices():
        dev = InputDevice(path)
        caps = dev.capabilities()
        # a real keyboard advertises EV_KEY with the letter/enter range
        if ecodes.EV_KEY in caps and ecodes.KEY_ENTER in caps[ecodes.EV_KEY]:
            return dev
    raise RuntimeError("no keyboard found")

dev = find_keyboard()
index = 0
running = True

def emit():
    print(json.dumps({"running": running, "index": index}), flush=True)

emit()  # send initial state immediately so QML has a starting point

for event in dev.read_loop():
    if event.type != ecodes.EV_KEY:
        continue
    key = categorize(event)
    if key.keystate != key.key_down:   # only act on press, not release/hold
        continue
    if key.keycode == "KEY_UP":
        index -= 1
        emit()
    elif key.keycode == "KEY_DOWN":
        index += 1
        emit()
    elif key.keycode in ("KEY_ENTER", "KEY_KPENTER"):
        running = False
        emit()
        break   # loop ends, process exits