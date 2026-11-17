#!/bin/sh
# greeter/session.sh - starts the session picked on the login screen (its command is the arguments)
# with its output thrown away. greetd runs on VT1, so anything the session prints would show as
# console text while the desktop starts. Installed to /etc/greetd/quickshell/ by install.sh.
exec "$@" >/dev/null 2>&1
