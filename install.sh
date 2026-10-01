#!/usr/bin/env bash
set -euo pipefail

MARKER='BRSCAN_SKEY'

source /usr/local/src/logger.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

param="${1:-false}"

case "$param" in
  -n) testRun='-a -nv' LEVEL='debug' ;;
  *) testRun='-a' LEVEL='false' ;;
esac

log "user : $USER"
debug "$REPO_DIR"

debug "opt/brother/scanner/brscan-skey/ >> /opt/brother/scanner/brscan-skey/"
sudo rsync "$testRun" \
  "$REPO_DIR/opt/brother/scanner/brscan-skey/" \
  /opt/brother/scanner/brscan-skey/

debug "etc/opt/brother/scanner/brscan-skey/ >> /etc/opt/brother/scanner/brscan-skey/"
sudo rsync -a "$testRun"\
  "$REPO_DIR/etc/opt/brother/scanner/brscan-skey/" \
  /etc/opt/brother/scanner/brscan-skey/

debug "usr/local/src/ >> /usr/local/src/"
sudo rsync "$testRun"\
  "$REPO_DIR/usr/local/src/" \
  /usr/local/src/

debug "etc/systemd/system/brscan-skey.service >> /etc/systemd/system/"
sudo rsync "$testRun"\
  "$REPO_DIR/etc/systemd/system/brscan-skey.service" \
  "/etc/systemd/system/"

if [[ ! -n "$testRun" ]]; then
  sudo ln -s "/etc/systemd/system/" \
    "/etc/systemd/system-sleep/brscan-skey.sleep"
else
  debug "ln -s /etc/systemd/system/ /etc/systemd/system-sleep/brscan-skey.sleep"
fi
