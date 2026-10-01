#!/usr/bin/env bash
set -euo pipefail

sudo systemctl daemon-reload

sudo systemctl enable brscan-skey.service

sudo systemctl restart brscan-skey.service
