#!/usr/bin/env bash
set -euo pipefail

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

set -o pipefail

##############################################################################
# Verwendung:
#     scanto.sh <auftrag> <gerät> <name> [parameter=value ...]
#
# Beschreibung:
#     Scannt ein Dokument mit einem Brother-Scanner und verarbeitet das
#     Ergebnis abhängig vom angegebenen Auftrag.
#
# Aufträge:
#     file
#         Speichert den Scan als Datei und öffnet anschließend das Zielverzeichnis
#         im Standard-Dateimanager.
#
#     email
#         Wandelt den Scan in das Zielformat um und erzeugt eine neue E-Mail
#         mit dem Scan als Anhang.
#
#     image
#         Wird derzeit wie "file" behandelt.
#
#     ocr
#         Wird derzeit ebenfalls wie "file" behandelt.
#         Eine tatsächliche Texterkennung ist noch nicht implementiert.
#
# Parameter:
#     <auftrag>
#         Einer der folgenden Werte: file, email, image oder ocr.
#
#     <gerät>
#         Gerätename des Scanners. Der Wert wird unverändert an das Brother-
#         Scanprogramm übergeben.
#
#     <name>
#         Benutzerfreundlicher Name des Scannerauftrags. Der Name wird derzeit
#         hauptsächlich für Protokollmeldungen verwendet.
#
#     [parameter=value ...]
#         Optionale Parameter. Sie überschreiben Werte aus der Konfiguration.
#
# Unterstützte optionale Parameter:
#     path=VERZEICHNIS
#         Zielverzeichnis relativ zum Home-Verzeichnis des Benutzers.
#         Standard: brscan
#
#     format=FORMAT
#         Format der vom Scanner erzeugten Datei.
#         Standard: tiff
#
#     fileName=DATEINAME
#         Dateiname ohne Erweiterung.
#         Standard: brscan-JJJJMMTT-HHMMSS
#
#     resolution=AUFLÖSUNG
#         Scanauflösung in DPI.
#         Standard: 100
#
#     size=FORMAT
#         Papierformat.
#         Standard: A4
#
#     scan_source=QUELLE
#         Scanquelle, zum Beispiel FlatBed.
#         Standard: FlatBed
#
#     delTime=ZEIT
#         Alter, ab dem alte Dateien gelöscht werden.
#         Zulässige Einheiten:
#
#             m   Minuten
#             h   Stunden
#             d   Tage
#             M   30-Tage-Monate
#
#         Beispiele:
#
#             delTime=30m
#             delTime=5h
#             delTime=2d
#             delTime=1M
#
#     targetFormat=FORMAT
#         Zielformat nach der Umwandlung mit ImageMagick.
#         Standard: pdf
#
#     quality=WERT
#         Qualitätswert für ImageMagick.
#         Standard: 40
#
#     compress=VERFAHREN
#         Kompressionsverfahren für ImageMagick.
#         Standard: zip
#
# Konfigurationsdateien:
#     Zuerst wird die benutzerspezifische Konfiguration geladen:
#
#         ~/.brscan-skey/scanto<auftrag>.config
#
#     Falls diese Datei nicht existiert, wird die Standardkonfiguration aus dem
#     übergeordneten Verzeichnis des Skripts geladen:
#
#         scanto<auftrag>.config
#
#     Beispiele:
#
#         scantofile.config
#         scantoemail.config
#
# Beispiel:
#
# Umgebungsbedingungen:
#     Das Skript benötigt:
#
#         - Bash
#         - Brother brscan-skey
#         - xdg-email
#         - xdg-mime
#         - gtk-launch
#         - ImageMagick mit dem Befehl "magick"
#         - ein grafisches Benutzerkonto mit gültiger Desktop-Sitzung
#             * Funktion geprüft mit KDE (Wayland, x11), und dem minimalen X11 System von OpenSuse)
#         - das Logger-Skript:
#             /usr/local/src/logger.sh
#
# Ausgabedateien:
#     Die vom Scanner erzeugte Datei wird zunächst im Scanformat gespeichert:
#
#         $HOME/<path>/<fileName>.<format>
#
#     Danach wird die Zieldatei erzeugt:
#
#         $HOME/<path>/<fileName>.<targetFormat>
#
#     Alte Dateien im Zielverzeichnis werden automatisch gelöscht, sobald sie
#     älter als die konfigurierte Löschfrist sind.
#
# Rückgabewerte:
#     0
#         Auftrag erfolgreich ausgeführt.
#
#     1
#         Allgemeiner Fehler, fehlende Konfiguration oder fehlgeschlagener Scan.
#
#     2
#         Benötigtes Programm oder benötigter Dienst nicht gefunden.
##############################################################################

###############################################################################
# Grundeinstellungen
###############################################################################

MARKER="BRSCAN_SKEY"

# Eigenes Logger-Skript laden.
LOGGER_SCRIPT="/usr/local/src/logger.sh"

if [[ ! -r "$LOGGER_SCRIPT" ]]; then
    echo "Fehler: Logger-Skript nicht gefunden: $LOGGER_SCRIPT" >&2
    exit 1
fi

# shellcheck source=/usr/local/src/logger.sh
source "$LOGGER_SCRIPT"

LEVEL="debug"

###############################################################################
# Benutzer- und Pfadinformationen
###############################################################################

CURRENT_USER="$(whoami)"
USER_HOME="${HOME:-/home/$CURRENT_USER}"

SCRIPT_NAME="$(basename "$0")"
ORIGIN_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$ORIGIN_PATH")"
STANDARD_CONFIG_DIR="$(realpath "$SCRIPT_DIR/..")"

USER_CONFIG_DIR="$USER_HOME/.brscan-skey"

# Brother brscan-skey
BROTHER_SCANNER_DIR="/opt/brother/scanner/brscan-skey"
SCANIMAGE="$BROTHER_SCANNER_DIR/skey-scanimage"

# Desktop-Dateien
APPLICATION_DIR="/usr/share/applications"

log "Benutzer: $CURRENT_USER ($(id "$CURRENT_USER"))"
log "Aufruf: $0 $*"
debug "SCRIPT_NAME: $SCRIPT_NAME"
debug "ORIGIN_PATH: $ORIGIN_PATH"
debug "STANDARD_CONFIG_DIR: $STANDARD_CONFIG_DIR"

###############################################################################
# Benötigte Programme ermitteln
###############################################################################

XDG_EMAIL="$(command -v xdg-email || true)"
XDG_MIME="$(command -v xdg-mime || true)"
GTK_LAUNCH="$(command -v gtk-launch || true)"
MAGICK="$(command -v magick || true)"

testCMD() {
    fEntry "test: '$*'"  
    local progamName="$1"
    if [[ ! -x "${progamName:-}" ]]; then
        error "Programm $progamName nicht gefunden oder nicht ausführbar"
        error 2
    fi
    debug "Programm $progamName gefunden und ausführbar"
}

testCMD "$XDG_EMAIL"
testCMD "$XDG_MIME"
testCMD "$GTK_LAUNCH"
testCMD "$SCANIMAGE"
testCMD "$MAGICK"

###############################################################################
# Standard-Dateimanager und Mailprogramm ermitteln
###############################################################################

# Standard-Dateimanager bestimmen.
FILE_MANAGER_DESKTOP="$(
    "$XDG_MIME" query default inode/directory 2>/dev/null
)"
    
if [[ -z "$FILE_MANAGER_DESKTOP" ||
    ! -f "$APPLICATION_DIR/$FILE_MANAGER_DESKTOP" ]]; then
    error "Kein Standard-Dateimanager gefunden."
    exit 2
fi

FILE_MANAGER="$(
    grep -m1 '^Exec=' "$APPLICATION_DIR/$FILE_MANAGER_DESKTOP" | cut -d= -f2- | cut -w -f1
)"

if [[ -z "$FILE_MANAGER" ]] ||
! command -v "$FILE_MANAGER" >/dev/null 2>&1; then
    error "Dateimanager nicht gefunden: $FILE_MANAGER"
    exit 2
fi

debug "Dateimanager: $FILE_MANAGER"
debug "Desktop-Datei des Dateimanagers: $FILE_MANAGER_DESKTOP"

# Standard-Mailprogramm bestimmen.
MAIL_CLIENT_DESKTOP="$(
    "$XDG_MIME" query default x-scheme-handler/mailto 2>/dev/null
)"

if [[ -z "$MAIL_CLIENT_DESKTOP" ||
      ! -f "$APPLICATION_DIR/$MAIL_CLIENT_DESKTOP" ]]; then
    error "Kein Standard-Mailprogramm gefunden."
    exit 2
fi

MAIL_CLIENT="$(
   grep -m1 '^Exec=' "$APPLICATION_DIR/$MAIL_CLIENT_DESKTOP" | cut -d= -f2- | cut -w -f1
)"

if [[ -z "$MAIL_CLIENT" ]] ||
   ! command -v "$MAIL_CLIENT" >/dev/null 2>&1; then
    error "Mailprogramm nicht gefunden: $MAIL_CLIENT"
    exit 2
fi

debug "Mailprogramm: $MAIL_CLIENT"
debug "Desktop-Datei des Mailprogramms: $MAIL_CLIENT_DESKTOP"

###############################################################################
# Kommandozeilenparameter auswerten
###############################################################################

if [[ $# -lt 1 ]]; then
    error "Kein Auftrag angegeben."
    echo "Aufruf: $SCRIPT_NAME <file|email|image|ocr> <device> <name> [key=value ...]" >&2
    exit 1
fi

REQUESTED_JOB="$1"
shift

# image und ocr werden derzeit wie file behandelt.
case "$REQUESTED_JOB" in
    file|email)
        JOB="$REQUESTED_JOB"
        ;;

    image|ocr)
        JOB="file"
        ;;

    *)
        error "Unbekannter Auftrag: $REQUESTED_JOB"
        exit 1
        ;;
esac

# Löschfrist in Minuten:
# file: 10 Tage
# email: 5 Stunden
case "$JOB" in
    file)
        DEFAULT_DELETE_TIME="14400m"
        ;;

    email)
        DEFAULT_DELETE_TIME="300m"
        ;;
esac

if [[ $# -lt 2 ]]; then
    error "Zu wenige Parameter."
    echo "Aufruf: $SCRIPT_NAME <job> <device> <friendly-name> [key=value ...]" >&2
    exit 1
fi

DEVICE="$1"
shift

FRIENDLY_NAME="$1"
shift

debug "JOB: $JOB"
debug "DEVICE: $DEVICE"
debug "FRIENDLY_NAME: $FRIENDLY_NAME"
debug "Zusätzliche Parameter: $#"

###############################################################################
# Zusätzliche Parameter key=value übernehmen
###############################################################################

# Die zusätzlichen Parameter werden als Variablen exportiert.
#
# Beispiel:
#   user=username
#   id=1005
#   type=wayland|x11
#   pid=2..
#   DBUS_SESSION_BUS_ADDRESS=...
#   XDG_RUNTIME_DIR=...
#   DISPLAY=...
#   XAUTHORITY=...
#   WAYLAND_DISPLAY=...
#
# Hinweis: Die Variablennamen stammen hier aus den Programmparametern.
# Bei unkontrollierten Aufrufen sollte zusätzlich eine Whitelist verwendet
# werden.
for key_value in "$@"; do
    key="${key_value%%=*}"
    value="${key_value#*=}"

    if [[ "$key_value" != *=* || -z "$key" ]]; then
        error "Ungültiger Parameter: $key_value"
        exit 1
    fi

    printf -v "$key" '%s' "$value"
    export "${key?}"

    debug "Parameter: $key=$value"
done

###############################################################################
# Konfigurationsdatei laden
###############################################################################

JOB_CONFIG="scanto${JOB}.config"
USER_CONFIG_FILE="$USER_CONFIG_DIR/$JOB_CONFIG"
STANDARD_CONFIG_FILE="$STANDARD_CONFIG_DIR/$JOB_CONFIG"

if [[ -r "$USER_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$USER_CONFIG_FILE"
    log "Benutzerkonfiguration geladen: $USER_CONFIG_FILE"

elif [[ -r "$STANDARD_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null

    debug "kopiere $STANDARD_CONFIG_FILE nach $USER_CONFIG_DIR"
    [[ ! -r "$USER_CONFIG_DIR" ]] && mkdir -p "$USER_CONFIG_DIR"
    [[ ! -r "$USER_CONFIG_FILE" ]] && cp "$STANDARD_CONFIG_FILE $USER_CONFIG_DIR" \
        chmod 644 "$USER_CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$STANDARD_CONFIG_FILE"
    log "Standardkonfiguration geladen: $STANDARD_CONFIG_FILE"

else
    error "Keine passende Konfiguration gefunden und keine Benutzerkonfiguration gespeichert"
    error "Gesucht wurde:"
    error "  $USER_CONFIG_FILE"
    error "  $STANDARD_CONFIG_FILE"
    exit 1
fi

###############################################################################
# Konfigurationswerte mit Standardwerten ergänzen
###############################################################################
#
# Der Typ des Sanners ist ein Flachbrettscanner ohne automatischem Blatteinzug
scan_size="${size:-A4}"
scan_source="${scan_source:-FlatBed}"

# Diese Default-Einstellungen sind unabhängig von Scanner
path="${path:-brscan}"
format="${format:-tiff}"
fileName="${fileName:-brscan-$(date +%Y%m%d-%H%M%S)}"
resolution="${resolution:-100}"
delete_time="${delTime:-$DEFAULT_DELETE_TIME}"
targetFormat="${targetFormat:-pdf}"
quality="${quality:-40}"
compress="${compress:-zip}"

debug "Konfiguration:"
debug "  size:          $scan_size"
debug "  source:        $scan_source"
debug "  path:          $path"
debug "  format:        $format"
debug "  fileName:      $fileName"
debug "  resolution:    $resolution"
debug "  delete_time:   $delete_time"
debug "  targetFormat:  $targetFormat"
debug "  quality:       $quality"
debug "  compress:      $compress"

###############################################################################
# Zeitangaben in Minuten umrechnen
###############################################################################

# Unterstützte Einheiten:
#
#   m = Minuten
#   h = Stunden
#   d = Tage
#   M = 30-Tage-Monate
#
# Beispiele:
#
#   30m  = 30 Minuten
#   5h   = 300 Minuten
#   2d   = 2880 Minuten
#   1M   = 43200 Minuten
#
convert_to_minutes() {
    local time_string="$1"
    local number
    local unit
    local multiplier

    if [[ "$time_string" =~ ^([0-9]+)([mhdM])$ ]]; then
        number="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
    elif [[ "$time_string" =~ ^[0-9]+$ ]]; then
        # Zahlen ohne Einheit werden als Minuten interpretiert.
        number="$time_string"
        unit="m"
    else
        error "Ungültige Zeitangabe: $time_string"
        return 1
    fi

    case "$unit" in
        m) multiplier=1 ;;
        h) multiplier=60 ;;
        d) multiplier=1440 ;;
        M) multiplier=43200 ;;
        *)
            error "Unbekannte Zeiteinheit: $unit"
            return 1
            ;;
    esac

    echo "$((number * multiplier))"
}

DELETE_MINUTES="$(convert_to_minutes "$delete_time")" || exit 1

###############################################################################
# Zielverzeichnis und Dateinamen festlegen
###############################################################################

OUTPUT_DIR="$USER_HOME/$path"
OUTPUT_FILE="$OUTPUT_DIR/$fileName.$format"
TARGET_FILE="$OUTPUT_DIR/$fileName.$targetFormat"

mkdir -p "$OUTPUT_DIR" || {
    error "Zielverzeichnis konnte nicht angelegt werden: $OUTPUT_DIR"
    exit 1
}

debug "OUTPUT_DIR: $OUTPUT_DIR"
debug "OUTPUT_FILE: $OUTPUT_FILE"
debug "TARGET_FILE: $TARGET_FILE"

###############################################################################
# Alte Dateien löschen
###############################################################################

log "Lösche Dateien, die älter als $DELETE_MINUTES Minuten sind."

find "$OUTPUT_DIR" \
    -maxdepth 1 \
    -type f \
    -mmin "+$DELETE_MINUTES" \
    -print \
    -delete

###############################################################################
# Alte Zieldateien entfernen
###############################################################################

rm -f "$OUTPUT_FILE" "$TARGET_FILE"

###############################################################################
# Scanoptionen zusammenstellen
###############################################################################

SCAN_OPTIONS=(
    "--device-name" "$DEVICE"
    "--resolution" "$resolution"
    "--source" "$scan_source"
    "--size" "$scan_size"
    "--outputfile" "$OUTPUT_FILE"
)

debug "Scanner: $SCANIMAGE ${SCAN_OPTIONS[*]}"

# Bei Netzwerk-Scannern kurz warten.
if [[ "$DEVICE" == *net* ]]; then
    sleep 1
fi

###############################################################################
# Scan ausführen
###############################################################################

if ! "$SCANIMAGE" "${SCAN_OPTIONS[@]}"; then
    error "Scan fehlgeschlagen."
    exit 1
fi

if [[ ! -s "$OUTPUT_FILE" ]]; then
    error "Die Scan-Datei wurde nicht erzeugt oder ist leer: $OUTPUT_FILE"
    exit 1
fi

log "Scan erfolgreich: $OUTPUT_FILE"

###############################################################################
# Scan in das Zielformat umwandeln
###############################################################################

debug "ImageMagick: $MAGICK $OUTPUT_FILE"
debug "Qualität: $quality"
debug "Kompression: $compress"
debug "Zieldatei: $TARGET_FILE"

if ! "$MAGICK" \
        "$OUTPUT_FILE" \
        -quality "$quality" \
        -compress "$compress" \
        "$TARGET_FILE"; then

    error "Umwandlung mit ImageMagick fehlgeschlagen."
    exit 1
fi

if [[ ! -s "$TARGET_FILE" ]]; then
    error "Die Zieldatei wurde nicht erzeugt oder ist leer: $TARGET_FILE"
    exit 1
fi

log "Zieldatei erzeugt: $TARGET_FILE"

###############################################################################
# Auftrag ausführen
###############################################################################

case "$JOB" in

    email)
        log "E-Mail-Auftrag gestartet."

        # Thunderbird beziehungsweise das Standard-Mailprogramm starten,
        # falls es noch nicht läuft.
        if ! pgrep -u "$CURRENT_USER" -x "$MAIL_CLIENT" >/dev/null 2>&1; then
            debug "Starte Mailprogramm: $MAIL_CLIENT_DESKTOP"

            "$GTK_LAUNCH" "$MAIL_CLIENT_DESKTOP" >/dev/null 2>&1 &
            sleep 3
        fi

        debug "prüfe Mailclient $MAIL_CLIENT"
        if ! pgrep -u "$CURRENT_USER" "$MAIL_CLIENT" >/dev/null 2>&1; then
            error "Mailprogramm konnte nicht gestartet werden: $MAIL_CLIENT"
            exit 1
        fi

        log "Erzeuge neue E-Mail mit Anhang."

        if ! "$XDG_EMAIL" \
                --attach "$TARGET_FILE" \
                --subject "Gescanntes Dokument" \
                "user@domain.sample"; then

            error "E-Mail konnte nicht erzeugt werden."
            exit 1
        fi
        ;;

    file)
        log "Dateiauftrag abgeschlossen."

        # Zielverzeichnis im Standard-Dateimanager öffnen.
        debug "Dateimanager $FILE_MANAGER mit $OUTPUT_DIR"
        "$GTK_LAUNCH" "$FILE_MANAGER_DESKTOP" "$OUTPUT_DIR" >/dev/null 2>&1 &
        ;;

    *)
        error "Interner Fehler: unbekannter Auftrag: $JOB"
        exit 1
        ;;

esac

exit 0
