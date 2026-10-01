# #!/bin/bash 
set -euo pipefail

# Entwicklung von debug/error/notice-logger
#
# Copyright (C) 2026 Ulf-Diethelm Kornblum <ulf@kornblum.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Usage:
#   source /path/to/logger.sh   Logger-Funktionen für Skripte
#
# Beschreibung:
#   Bash-Logger für debug/error/notice/proc-Ausgaben.
#   Das Script ist dafür gedacht, per "source" eingebunden zu werden.
#   Beim direkten Start wird nur diese Hilfe ausgegeben.
#
# Variablen:
#
#   LEVEL=debug        aktiviert debug- und proc-Ausgaben
#   MARKER=TEXT        Präfix für Log-Meldungen
#
#   $BASENAME          Name des aufrufenden Scripts
#   $SCRIPT_NAME       Name des aufrufenden Scripts
#   $SCRIPT_DIR        Pfad des aufrufenden Scripts
#   $ORIGIN_PATH       originaler Name des aufrufenden Scripts
#   $ORIGIN_NAME       originaler Pfad des aufrufenden Scripts
#
#   NO_COLOR=1         deaktiviert Farbausgabe
#   LOG_INSTALL=true   nutzt bereits installierte Logger-Funktionen
#
# Bereitgestellte Funktionen:
#   log "TEXT"         normale Meldung
#   error "TEXT"       Fehlermeldung
#   debug "TEXT"       Debug-Meldung (nur bei LEVEL=debug)
#   fEntry "TEXT" $*   Funktions-/Protokollausgabe (nur bei LEVEL=debug)
#   
# - Es erwartet:
#       /usr/bin/logger.sh
#
# Beispiele:
#   source /path/to/logger.sh
#   LEVEL=debug source /path/to/logger.sh
#   MARKER=MYAPP LEVEL=debug source /path/to/logger.sh

LEVEL="${LEVEL:-false}"

if [ "${LOG_INSTALL:-false}" == "true" ]; then

    log "Logger is installed"

else

    LOGGERDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    loggDirArray="${BASH_SOURCE[@]}"

    BASENAME=$(basename "${0}")
    SCRIPT_DIR=$(dirname "${BASH_SOURCE[1]:-$BASENAME}")
    SCRIPT_NAME=$(basename "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")
    ORIGIN_PATH="$(dirname "$(readlink -f "$0")")"
    ORIGIN_NAME="$(basename "$(readlink -f "$0")")"

    USER="$(whoami)"
    uID=$(id -u "$USER")
    gID=$(id -g "$USER")
    GROUP=$(id -ng "$USER")

    MARKER=${MARKER:-''}

    LOGTYPE='echo'

    # /siehe https://commandlinux.com/qa/echo-color-code/
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        LOGTYPE='echo'

        BLACK=$(tput setaf 0 2>/dev/null || printf '')
        RED=$(tput setaf 1 2>/dev/null || printf '')
        GREEN=$(tput setaf 2 2>/dev/null || printf '')
        YELLOW=$(tput setaf 3 2>/dev/null || printf '')
        BLUE=$(tput setaf 4 2>/dev/null || printf '')
        LILA=$(tput setaf 5 2>/dev/null || printf '')
        CYAN=$(tput setaf 6 2>/dev/null || printf '')
        BOLD=$(tput bold 2>/dev/null || printf '')
        RESET=$(tput sgr0 2>/dev/null || printf '')
    else
        LOGTYPE='logger'
        BLACK=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; LILA=''; CYAN=''; BOLD=''; RESET=''
    fi

    # C_LOG=$BLACK #standard
    C_DEBUG=$CYAN
    C_ERROR=$RED

    _LOG_="log_${LOGTYPE}"
    _ERROR_="error_${LOGTYPE}"
    _DEBUG_="debug_${LOGTYPE}"
    _PROC_="proc_${LOGTYPE}"

    log_logger () {
        logger -t "$MARKER" -p lpr.notice "[${BASENAME}:${FUNCNAME[2]:-main}: ${BASH_LINENO[1]}] $*"
    }

    error_logger () {
        logger -t "$MARKER" -p lpr.error "[error - ${BASENAME}:${FUNCNAME[2]:-main}: ${BASH_LINENO[1]}] $*"
    }

    debug_logger () {
        if [ "${LEVEL}" == 'debug' ]; then
            logger -t "$MARKER" -p lpr.debug "[debug - ${BASENAME}:${FUNCNAME[2]:-main}: ${BASH_LINENO[1]}] $*"
        fi
    }

    proc_logger () {
        if [ "${LEVEL}" == 'debug' ]; then
            logger -t "$MARKER" -p lpr.debug "[debug-proc - ${BASENAME}:call ${FUNCNAME[2]:-main}: ${BASH_LINENO[2]}] $*"
        fi
    }

    log_echo () {
        echo -n "[$(date +"%m-%d %H:%M:%S") $MARKER${BASENAME}:${FUNCNAME[2]:-main}: ${BASH_LINENO[1]}]"
        echo " $*"
    }

    error_echo () {
        echo -n "$C_ERROR\[$(date +"%m-%d %H:%M:%S") error - $MARKER${BASENAME}:${FUNCNAME[2]:-main}: ${BASH_LINENO[1]}\]$RESET"
        echo " $*"
    }

    debug_echo () {
        if [ "${LEVEL}" == 'debug' ]; then
            echo -n "$C_DEBUG\[$(date +"%m-%d %H:%M:%S") debug - $MARKER${BASENAME}:${FUNCNAME[2]:-main}: ${BASH_LINENO[1]}\]$RESET"
            echo " $*"
        fi
    }

    proc_echo () {
        if [ "${LEVEL}" == 'debug' ]; then
            echo -n "$C_DEBUG\[$(date +"%m-%d %H:%M:%S") $MARKER${BASENAME}:call ${FUNCNAME[2]:-main}: ${BASH_LINENO[2]}\]$RESET"
            echo " $*"
        fi
    }
    
    # 
    log () {
        ${_LOG_} "$*"
    }

    error () {
        ${_ERROR_} "$*"
    }

    debug () {
        ${_DEBUG_} "$*"
    }

    fEntry () {
        ${_PROC_} "$*"
    }

    LOG_INSTALL='true'

    trap 'error $BASH_COMMAND' ERR

    debug "loggDirArray: '${loggDirArray}'"

    debug "LOGGERDIR: ${LOGGERDIR}"
    debug "BASENAME: ${BASENAME}"

    debug "SCRIPT_DIR: ${SCRIPT_DIR}"
    debug "SCRIPT_NAME: ${SCRIPT_NAME}"

    debug "ORIGIN_PATH: ${ORIGIN_PATH}"
    debug "ORIGIN_NAME: ${ORIGIN_NAME}"

    debug "USER: ${USER}(uID:${uID})"
    debug "GROUP: ${GROUP}(gID:${gID})"

fi
