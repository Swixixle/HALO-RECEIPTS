#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: scripts/verify.sh <transcript_file> <receipt_json>"
  exit 2
fi

python3 scripts/verify.py "$1" "$2"
