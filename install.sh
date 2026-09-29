#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo rsync -a \
  "$REPO_DIR/opt/brother/scanner/brscan-skey/" \
  /opt/brother/scanner/brscan-skey/

sudo rsync -a \
  "$REPO_DIR/etc/opt/brother/scanner/brscan-skey/" \
  /etc/opt/brother/scanner/brscan-skey/

sudo rsync -a \
  "$REPO_DIR/usr/local/src/" \
  /usr/local/src/
