# #/bin/bash 
# set -euo pipefail

# Usage:
#   source /path/to/getActiveUser.sh
#
# Beschreibung:
#   Dieses Script ist zum Einbinden via "source" gedacht und ermittelt die aktuell
#   aktive grafische Benutzersitzung (Wayland oder X11). Dabei werden passende
#   Umgebungsvariablen in einem Array gesammelt, um sie anschließend für andere
#   Kommandos weiterzuverwenden.
#
# Funktion:
#   - ermittelt aktive Session via loginctl
#   - liest User, Session-ID, Typ, PID, Display und RuntimePath
#   - setzt Fallbacks für:
#       DBUS_SESSION_BUS_ADDRESS
#       XDG_RUNTIME_DIR
#       WAYLAND_DISPLAY
#       DISPLAY
#       XAUTHORITY
#   - gibt Debug-Informationen über logger.sh aus
#
# Wichtig:
#   - Es erwartet:
#       /usr/local/src/logger.sh
#       /usr/bin/loginctl
#       /usr/bin/sudo
#       /usr/bin/find
#
# Beispiel:
#   source /path/to/getActiveUser.sh
#   printf '%s\n' "${env_vars[@]}"
#
# Hinweis:
#   Die Variable env_vars enthält anschließend die gefundenen/gesetzten Einträge
#   im Format key=value.

MARKER='BRSCAN_SKEY'

source /usr/local/src/logger.sh

debug "actual USER: ${USER}"

while read session activeID activeUser seat rest; do
	debug "    -- session:${session}, activeID:${activeID}, activeUser:${activeUser}, seat:${seat}, ...${rest}"
	type="$(loginctl show-session "$session" -p Type --value)"
	state="$(loginctl show-session "$session" -p State --value)"
	pid="$(loginctl show-session "$session" -p Leader --value)"
	display="$(loginctl show-session "$session" -p Display --value)"
	runtime=$(loginctl show-user "${activeUser}" -p RuntimePath --value)
	debug "    -- type : ${type}, state : ${state}, pid : $pid, display : $display, runtime : $runtime"
	[[ "${type}" =~ ^wayland|x11$ ]] && [ "${state}" == "active" ] && break
done <<<"$(loginctl list-sessions --no-legend)"

[[ -z "${activeUser}" ]] && exit 1

debug "--- found session:${session}, activeID:${activeID}, activeUser:${activeUser}, type:${type}, state:${state}, pid:$pid"
debug "-- ACTIVE_USER: ${activeUser}(${activeID})"

env_vars=(
	"user=${activeUser}"
	"id=${activeID}"
	"type=${type}"
	"pid=${pid}"
)

XAUTHORITY="$(sudo -u "${activeUser}" find "/tmp" -maxdepth 1 -type f -user "${activeUser}" -name 'xauth*')"
debug "XAUTHORITY: $XAUTHORITY"

# Fallbacks from loginctl/session
has_var() { printf '%s\n' "${env_vars[@]}" | grep -q "^$1="; }

has_var DBUS_SESSION_BUS_ADDRESS || env_vars+=("DBUS_SESSION_BUS_ADDRESS=unix:path=${runtime:-/run/user/$activeID}/bus")
has_var XDG_RUNTIME_DIR || env_vars+=("XDG_RUNTIME_DIR=${runtime:-/run/user/$activeID}")

case "$type" in

	wayland)
		has_var WAYLAND_DISPLAY || env_vars+=("WAYLAND_DISPLAY=$(sudo -u "${activeUser}" \
			find "/run/user/1001" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null )")
	;;
# :::::::::::::::

	x11)
		has_var DISPLAY || env_vars+=("DISPLAY=${display:-:0}")
		has_var XAUTHORITY || env_vars+=("XAUTHORITY=$(sudo -u "${activeUser}" \
			find "/tmp" -maxdepth 1 -type f -user "${activeUser}" -name 'xauth*')")
	;;
# :::::::::::::::

esac

has_var DISPLAY || env_vars+=("DISPLAY=${display:-:0}")
has_var XAUTHORITY || env_vars+=("XAUTHORITY=/home/${activeUser}/.Xauthority")
has_var WAYLAND_DISPLAY || env_vars+=("WAYLAND_DISPLAY=wayland-0")

debug "${env_vars[@]}"


