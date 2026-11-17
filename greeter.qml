// greeter.qml - the login screen (greetd greeter), one surface per monitor.
//
// Runs as the `greeter` user inside a small Hyprland (greeter/hyprland.lua), started by greetd
// (/etc/greetd/config.toml). It cannot read ~/.config, so greeter/install.sh copies this file,
// lockscreen/ and the wallpapers to /etc/greetd/quickshell: run it again after changing the look.
//
// The look is lockscreen/LockSurface.qml, shared with the lock screen (LockScreen.qml).
// Without greetd (e.g. testing it in a window) it shows everything but cannot log in.

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import "lockscreen"

ShellRoot {
    id: greeter

    // ── Tweakables ──
    property string user: "thekingg"                       // who logs in (single-user machine)
    property string wallpaperDir: Qt.resolvedUrl("wallpapers")
    function wallpaperFor(screenName) {
        return wallpaperDir + (screenName === "HDMI-A-1" ? "/wide.png" : "/normal.png")
    }
    // Sessions to pick from (click the name at the bottom). The first one is the default.
    property var sessions: [
        { name: "Hyprland", command: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"], desktop: "Hyprland" },
        { name: "Plasma",   command: ["/usr/lib/plasma-dbus-run-session-if-needed", "/usr/bin/startplasma-wayland"], desktop: "KDE" }
    ]
    property color colSubtext: "#a6adc8"

    // ── State ──
    property int sessionIndex: 0
    property string password: ""
    property bool busy: false
    property string errorText: ""
    property string displayName: user   // login name shown above the password box

    function submit() {
        if (busy || password.length === 0) return
        if (!Greetd.available) { errorText = "greetd is not running (test mode)"; password = ""; return }
        busy = true
        errorText = ""
        Greetd.createSession(user)
    }

    function fail(message) {
        busy = false
        password = ""
        errorText = message
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(greeter.password)
            else if (error) greeter.errorText = message
        }
        function onAuthFailure(message) { greeter.fail("Wrong password") }
        function onError(error) { greeter.fail(error) }
        function onReadyToLaunch() {
            const s = greeter.sessions[greeter.sessionIndex]
            // Through greeter/session.sh, which silences the session's output (it would show as text on VT1)
            Greetd.launch(["/etc/greetd/quickshell/session.sh"].concat(s.command), [
                "XDG_SESSION_TYPE=wayland",
                "XDG_CURRENT_DESKTOP=" + s.desktop,
                "XDG_SESSION_DESKTOP=" + s.desktop
            ], true)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "#11111b"

            LockSurface {
                anchors.fill: parent
                wallpaper: greeter.wallpaperFor(win.screen.name)
                userName: greeter.displayName
                passwordLength: greeter.password.length
                busy: greeter.busy
                errorText: greeter.errorText

                onTyped: (t) => { if (!greeter.busy) { greeter.password += t; greeter.errorText = "" } }
                onErased: if (!greeter.busy) greeter.password = greeter.password.slice(0, -1)
                onCleared: if (!greeter.busy) greeter.password = ""
                onSubmitted: greeter.submit()

                // Session picker: click to cycle
                Text {
                    text: "\u{f0379}  " + greeter.sessions[greeter.sessionIndex].name
                    color: greeter.colSubtext
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: greeter.sessionIndex = (greeter.sessionIndex + 1) % greeter.sessions.length
                    }
                }
            }
        }
    }
}
