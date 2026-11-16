-- greeter/hyprland.lua - the small Hyprland that greetd runs for the login screen.
-- Installed to /etc/greetd/quickshell/greeter/ by install.sh. It only shows the Quickshell
-- greeter, then exits once the greeter has handed over to the chosen session.

-- Same monitor setup as ~/.config/hypr/monitors.lua (laptop panel is eDP-1 or eDP-2)
for _, out in ipairs({ "eDP-1", "eDP-2" }) do
    hl.monitor({ output = out, mode = "2560x1600@240.0", position = "2560x118", scale = 1.3333334 })
end
hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@143.94", position = "0x118", scale = 1.0 })

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
    input = { kb_layout = "us" },
    animations = { enabled = false },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p /etc/greetd/quickshell/greeter.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)
