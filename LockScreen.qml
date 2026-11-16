// LockScreen.qml - the lock screen (Wayland session lock), one surface per monitor.
//
// Locked over IPC: `qs ipc call lock lock` (Super+L in ~/.config/hypr/keybinds.lua, the power
// menu's Lock button, and hypridle before sleep / on `loginctl lock-session`). Unlocked only by the
// password, checked through PAM (/etc/pam.d/login, which also counts failed tries: too many and
// PAM refuses for a while, shown as the error text).
//
// The look lives in lockscreen/LockSurface.qml, shared with the greetd login screen (greeter/).

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import "lockscreen"

Scope {
    id: lockScreen
    property var root

    // ── Tweakables ──
    // Same files as ~/.config/hypr/hyprpaper.conf: the ultrawide gets its own crop
    property string wallpaperDir: root.homeDir + "/Pictures/wallpapers"
    function wallpaperFor(screenName) {
        return "file://" + wallpaperDir + (screenName === "HDMI-A-1"
            ? "/widescreen_2560x1080/wallhaven-d8km7l_2560x1080.png"
            : "/normal_2560x1600/wallhaven-d8km7l_2560x1600.png")
    }

    // ── State ── one password for every monitor, so typing shows on all of them
    property string password: ""
    property bool busy: false
    property string errorText: ""
    property string displayName: Quickshell.env("USER")   // login name shown above the password box

    function lock() {
        password = ""; errorText = ""; busy = false
        sessionLock.locked = true
    }

    function submit() {
        if (busy || password.length === 0) return
        busy = true
        errorText = ""
        if (!pam.start()) { busy = false; errorText = "Could not start PAM" }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurface
            color: "#11111b"

            LockSurface {
                anchors.fill: parent
                fontFamily: lockScreen.root.fontFamily
                wallpaper: lockScreen.wallpaperFor(lockSurface.screen ? lockSurface.screen.name : "")
                userName: lockScreen.displayName
                passwordLength: lockScreen.password.length
                busy: lockScreen.busy
                errorText: lockScreen.errorText

                onTyped: (t) => { if (!lockScreen.busy) { lockScreen.password += t; lockScreen.errorText = "" } }
                onErased: if (!lockScreen.busy) lockScreen.password = lockScreen.password.slice(0, -1)
                onCleared: if (!lockScreen.busy) lockScreen.password = ""
                onSubmitted: lockScreen.submit()
            }
        }
    }

    PamContext {
        id: pam
        onPamMessage: {
            if (responseRequired) respond(lockScreen.password)
            else if (messageIsError) lockScreen.errorText = message
        }
        onCompleted: (result) => {
            lockScreen.busy = false
            lockScreen.password = ""
            if (result === PamResult.Success) {
                lockScreen.errorText = ""
                sessionLock.locked = false
            } else if (result === PamResult.MaxTries) {
                lockScreen.errorText = "Too many tries, wait a bit"
            } else if (!lockScreen.errorText) {
                lockScreen.errorText = "Wrong password"
            }
        }
        onError: (error) => {
            lockScreen.busy = false
            lockScreen.password = ""
            lockScreen.errorText = "PAM error: " + PamError.toString(error)
        }
    }


    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen.lock() }
        function isLocked(): bool { return sessionLock.locked }
    }
}
