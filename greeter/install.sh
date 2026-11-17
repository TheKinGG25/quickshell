#!/usr/bin/env bash
# greeter/install.sh - installs the Quickshell login screen for greetd. Run with sudo.
#
#   sudo ~/.config/quickshell/greeter/install.sh            copy the files (after changing the look)
#   sudo ~/.config/quickshell/greeter/install.sh --enable   also set up greetd and make it the
#                                                           login manager from the next boot
#
# The greeter runs as the `greeter` user, which cannot read ~/.config, so everything it needs is
# copied to /etc/greetd/quickshell: greeter.qml, lockscreen/ (the look shared with the lock
# screen), the wallpapers, the small Hyprland it runs in (hyprland.lua) and session.sh, which
# starts the chosen session with its output silenced.
#
# Go back to Plasma Login Manager:
#   sudo systemctl disable greetd && sudo systemctl enable plasmalogin   (then reboot)
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }

SRC="$(cd "$(dirname "$0")/.." && pwd)"                  # ~/.config/quickshell
WALL="$(getent passwd "${SUDO_USER:-thekingg}" | cut -d: -f6)/Pictures/wallpapers"
DEST=/etc/greetd/quickshell

command -v greetd >/dev/null || { echo "greetd is not installed: paru -S greetd" >&2; exit 1; }

echo "Copying the greeter to $DEST"
rm -rf "$DEST"
install -d -m 755 "$DEST" "$DEST/lockscreen" "$DEST/wallpapers"
install -m 644 "$SRC/greeter.qml"                  "$DEST/greeter.qml"
install -m 644 "$SRC/lockscreen/"*.qml             "$DEST/lockscreen/"
install -m 644 "$SRC/greeter/hyprland.lua"         "$DEST/hyprland.lua"
install -m 755 "$SRC/greeter/session.sh"           "$DEST/session.sh"
install -m 644 "$WALL/normal_2560x1600/wallhaven-d8km7l_2560x1600.png"     "$DEST/wallpapers/normal.png"
install -m 644 "$WALL/widescreen_2560x1080/wallhaven-d8km7l_2560x1080.png" "$DEST/wallpapers/wide.png"

[[ "${1:-}" == "--enable" ]] || { echo "Done."; exit 0; }

backup() { [[ -e "$1" && ! -e "$1.orig" ]] && cp -a "$1" "$1.orig" || true; }

echo "Writing /etc/greetd/config.toml (old one kept as config.toml.orig)"
backup /etc/greetd/config.toml
cat > /etc/greetd/config.toml <<'EOF'
# Quickshell login screen, see ~/.config/quickshell/greeter/install.sh
[terminal]
vt = 1

[default_session]
# Output goes to /dev/null, else Hyprland's log shows as text on VT1 before and after the login screen
command = "sh -c 'exec start-hyprland -- --config /etc/greetd/quickshell/hyprland.lua >/dev/null 2>&1'"
user = "greeter"
EOF

# Same as Plasma Login Manager's (/usr/lib/pam.d/plasmalogin), so KWallet still unlocks at login
echo "Writing /etc/pam.d/greetd (old one kept as greetd.orig)"
backup /etc/pam.d/greetd
cat > /etc/pam.d/greetd <<'EOF'
#%PAM-1.0
# Copied from /usr/lib/pam.d/plasmalogin so KWallet unlocks at login (pam_kwallet5)
auth        include     system-login
-auth       optional    pam_gnome_keyring.so
-auth       optional    pam_kwallet5.so

account     include     system-login

password    include     system-login
-password   optional    pam_gnome_keyring.so    use_authtok

session     optional    pam_keyinit.so          force revoke
session     include     system-login
-session    optional    pam_gnome_keyring.so    auto_start
-session    optional    pam_kwallet5.so         auto_start
EOF

echo "Switching the login manager: plasmalogin -> greetd (from the next boot)"
systemctl disable plasmalogin.service
systemctl enable greetd.service
echo "Done. Reboot to see it. If it fails: Ctrl+Alt+F2, log in, and run"
echo "  sudo systemctl disable greetd && sudo systemctl enable plasmalogin && sudo reboot"
