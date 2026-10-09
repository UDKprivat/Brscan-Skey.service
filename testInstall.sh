#!/usr/bin/env bash

# Bei Fehlern sofort abbrechen:
# -e: Abbruch bei Fehlern
# -u: Abbruch bei nicht gesetzten Variablen
# -o pipefail: Fehler innerhalb von Pipelines weiterreichen
set -euo pipefail

###############################################################################
# Globale Konfiguration
###############################################################################

# Kennzeichnung beziehungsweise Basisverzeichnis der Brother-Scanner-Dateien.
MARKER="BRSCAN_SKEY"

# Zentrales Logging-Script einbinden.
if [[ -s "usr/local/src/logger.sh" ]] ; then
  source "usr/local/src/logger.sh"
fi

# Eigentümer und Gruppenzugehörigkeiten.
USR_GRP_A="root:scanner"
USR_GRP_B="root:users"


###############################################################################
# Zeitstempel einer ausführbaren Datei ändern.
###############################################################################

# Zeitstempel für Dateien auf einen Monat zurücksetzen.
TOUCHTIME="1 month ago"

# Die Datei wird nur bearbeitet, wenn sie existiert und ausführbar ist.
set_time_exec_file() {
    local file="$1"

    if [[ -x "$file" ]]; then
        touch -d "$TOUCHTIME" "$file"
    fi
}

# Zeitstempel einer vorhandenen und nicht leeren Datei ändern.
set_time_file() {
    local file="$1"

    if [[ -s "$file" ]]; then
        touch -d "$TOUCHTIME" "$file"
    fi
}


###############################################################################
# Verzeichnisse und Pfade
###############################################################################

# Verzeichnis, in dem sich dieses Script befindet.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"

# Echtes Root-Dateisystem als Installationsziel.
ROOT_DIR="/"

# Testzielverzeichnis.
TST_DIR="$( readlink -f "${ROOT_DIR}/tmp/TstBRSCAN" )/"

# Erster Parameter:
# -n  = Installation in das Testverzeichnis
# sonst = Installation direkt in das Root-Dateisystem
PARAM="${1:-false}"

# Relative Pfade innerhalb des Repositorys beziehungsweise unterhalb von DEST.
BRSCAN_SKEY="opt/brother/scanner/brscan-skey"
ETC_BRSCAN_SKEY="etc/${BRSCAN_SKEY}"

ETC_SYSTEMD="etc/systemd"
ETC_SYSTEMD_SYSTEM="${ETC_SYSTEMD}/system"
ETC_SYSTEMD_SLEEP="${ETC_SYSTEMD}/system-sleep"
ETC_FIREWALL_SERVICE="etc/firewalld/services"

USR_LOCAL_SRC="usr/local/src"


###############################################################################
# HilfeText ausgeben
###############################################################################

usage() {
    cat <<EOF
Verwendung: ${0##*/} OPTION

Installiert die Brother-Scanner-Dateien entweder in ein Testverzeichnis
oder direkt in das Root-Dateisystem.

Optionen:
  --test,     Testinstallation nach ${TST_DIR}
  --install   Produktivinstallation nach /
  --rmTest    Testverzeichnis ${TST_DIR} löschen
  -h, --help  Diese Hilfe anzeigen

Zielverzeichnisse:

  BRSCAN_SKEY          [/ | ${TST_DIR}]$BRSCAN_SKEY
  ETC_BRSCAN_SKEY      [/ | ${TST_DIR}]etc/${BRSCAN_SKEY}

  ETC_SYSTEMD          [/ | ${TST_DIR}]etc/systemd
  ETC_SYSTEMD_SYSTEM   [/ | ${TST_DIR}]${ETC_SYSTEMD}/system
  ETC_SYSTEMD_SLEEP    [/ | ${TST_DIR}]${ETC_SYSTEMD}/system-sleep
  ETC_FIREWALL_SERVICE [/ | ${TST_DIR}]etc/firewalld/services

  USR_LOCAL_SRC        [/ | ${TST_DIR}]usr/local/src

Beispiele:
  ${0##*/} --install
  ${0##*/} --help
EOF
}


###############################################################################
# Hilfsfunktionen
###############################################################################

# Dateien aus dem Repository in das Zielverzeichnis kopieren.
#
# Argument:
#   $1 - relativer Pfad innerhalb des Repositorys und des Zielverzeichnisses
RSYNC_COPY() {
    local rel_path="$1"

    debug \
        "rsync ${RSYNC_PARAM} ${REPO_DIR}${rel_path}/ ${DEST}${rel_path}/"

    rsync \
        "${RSYNC_PARAM}" \
        "${REPO_DIR}${rel_path}/" \
        "${DEST}${rel_path}/"
}


###############################################################################
# Brother-Scanner-Dateien
###############################################################################

BRSCAN_FILES() {
    log "destination: ${DEST}${BRSCAN_SKEY}"
    cd "${DEST}${BRSCAN_SKEY}"

    debug "${USER}: $(pwd)"

    # Dateien aus dem Repository kopieren.
    RSYNC_COPY "$BRSCAN_SKEY"

    # Besitzer und Berechtigungen setzen.
    chown -R "$USR_GRP_A" "../"
    chmod 0755 "brscan-skey"
    chmod 0644 "brscan-skey.config"

    # Installierte Dateien zur Kontrolle anzeigen.
    log "$(ls -lsa .)"
}


###############################################################################
# Konfigurations- und Skript-Dateien von brscan-skey
###############################################################################

ETC_BRSCAN_FILES() {
    log "destination: ${DEST}${ETC_BRSCAN_SKEY}"
    cd "${DEST}${ETC_BRSCAN_SKEY}"

    debug "${USER}: $(pwd)"

    # Das komplette Verzeichnis "etc/opt/..." kopieren.
    RSYNC_COPY "${ETC_BRSCAN_SKEY}"

    # Standardbesitzer für die Konfigurationsdateien setzen.
    chown -R "$USR_GRP_A" "../"

    # scanto.sh soll von der Gruppe "users" ausgeführt beziehungsweise
    # bearbeitet werden können.
    chown "$USR_GRP_B" "script/scanto.sh"

    # Ausführungsrechte setzen.
    chmod 0755 \
        "script/scanto.sh" \
        "script/scantoSwitch.sh"

    # Installierte Dateien zur Kontrolle anzeigen.
    ls -lsa .
    ls -lsa ./script/*
}


###############################################################################
# Systemd-Service
###############################################################################

ETC_SYSTEMD_SYSTEM_FILES() {
    log "destination: ${DEST}${ETC_SYSTEMD_SYSTEM}"
    cd "${DEST}${ETC_SYSTEMD_SYSTEM}"

    debug "${USER}: $(pwd)"

    # Service-Datei kopieren.
    RSYNC_COPY "$ETC_SYSTEMD_SYSTEM"

    # Ausführungsrechte setzen.
    chmod 0755 "brscan-skey.service"

    # Installierte Dateien zur Kontrolle anzeigen.
    ls -lsa .
}

###############################################################################
# Firewall-Service 
###############################################################################

ETC_FIREWALL_SERVICE_FILES() {
    log "destination: ${DEST}${ETC_FIREWALL_SERVICE}"
    cd "${DEST}${ETC_FIREWALL_SERVICE}"

    debug "${USER}: $(pwd)"

    # Service-Datei kopieren.
    RSYNC_COPY "$ETC_FIREWALL_SERVICE"

    # Ausführungsrechte setzen.
    chmod 0644 "brscanskey.xml"

    # Installierte Dateien zur Kontrolle anzeigen.
    ls -lsa .
}

###############################################################################
# Zentrales Logging-Script
###############################################################################

USR_LOCAL_SRC_FILES() {
    log "destination: ${DEST}${USR_LOCAL_SRC}"
    cd "${DEST}${USR_LOCAL_SRC}"

    debug "${USER}: $(pwd)"

    # Logging-Script kopieren.
    RSYNC_COPY "$USR_LOCAL_SRC"

    # Ausführungsrechte setzen.
    chmod 0755 "logger.sh"

    # Installierte Dateien zur Kontrolle anzeigen.
    ls -lsa .
}


###############################################################################
# Systemd-Sleep-Symlink
###############################################################################

ETC_SYSTEMD_SLEEP_LN() {
    log "destination: ${DEST}${ETC_SYSTEMD_SLEEP}"
    cd "${DEST}${ETC_SYSTEMD_SLEEP}"

    debug "${USER}: $(pwd)"

    # Symlink zum Brother-Scanner-Programm anlegen.
    #
    # Das Ziel ist relativ zum Verzeichnis:
    # /etc/systemd/system-sleep/
    ln -srf \
        "${DEST}${BRSCAN_SKEY}/brscan-skey" \
        "${DEST}${ETC_SYSTEMD_SLEEP}/brscan-skey.sleep"

    # Symlink zur Kontrolle anzeigen.
    ls -lsa .
}


###############################################################################
# Testverzeichnis vorbereiten
###############################################################################

mkTestDir() {
    # Zielverzeichnis anlegen und dorthin wechseln.
    debug "Erstelle das TestVerzeichnis"

    mkdir -pv "$DEST"

    # ins Zielverzeichnis wechseln
    cd "$DEST"

    # Verzeichnisstruktur für den Testlauf erzeugen.
    mkdir -pv "./${BRSCAN_SKEY}"
    mkdir -pv "./${ETC_BRSCAN_SKEY}"
    mkdir -pv "./${ETC_SYSTEMD_SYSTEM}"
    mkdir -pv "./${ETC_SYSTEMD_SLEEP}"
    mkdir -pv "./${USR_LOCAL_SRC}"
    mkdir -pv "./${ETC_FIREWALL_SERVICE}"
}


###############################################################################
# Ausführungsmodus auswählen
###############################################################################

case "$PARAM" in
    --test)
      # Testmodus:
      # Nur Dateien in das lokale Testverzeichnis kopieren.
      RSYNC_PARAM="-rltDvci"
      LEVEL="debug"
      DEST="$TST_DIR"
      debug "Testmodus: Ziel: ${DEST}"

      # Testverzeichnis vorbereiten.
      mkTestDir
      ;;

    --install)
      # Produktivmodus:
      # Dateien direkt in das Root-Dateisystem kopieren.
      RSYNC_PARAM="-rltDvci"
      LEVEL="false"
      DEST="$ROOT_DIR"
      log "Installation:"
      ;;

    --rmTest)
      # löscht das Testverzeichnis
        log "lösche $TST_DIR"
        rm -rf "$TST_DIR"
        # Zurück in das Repository-Verzeichnis wechseln und beenden.
        cd "$REPO_DIR"
        exit
      ;;

    -h | --help)
      # Hilfe ausgeben
      usage
      exit 0
    ;;

    *)
      # Hilfe ausgeben
      usage
      exit 0
    ;;

esac

# Dateien und Verzeichnisse installieren. 
BRSCAN_FILES
ETC_BRSCAN_FILES
ETC_SYSTEMD_SYSTEM_FILES
ETC_FIREWALL_SERVICE_FILES
USR_LOCAL_SRC_FILES
ETC_SYSTEMD_SLEEP_LN

###############################################################################
# Produktivinstallation
###############################################################################

log "user : ${USER}"
debug "$REPO_DIR"

# Zurück in das Repository-Verzeichnis wechseln und beenden.

cd "$REPO_DIR"

exit 0