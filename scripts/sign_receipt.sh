#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/sign_receipt.sh <receipt_json>"
  exit 2
fi

RECEIPT="$1"
PAYLOAD="${RECEIPT%.json}.payload"
SIG="${PAYLOAD}.sig"

# Regenerate deterministically (avoid overwrite prompts / stale sigs)
rm -f "$PAYLOAD" "$SIG"

python3 scripts/receipt_payload.py "$RECEIPT" > "$PAYLOAD"
ssh-keygen -Y sign -f keys/halo_ed25519 -n halo-receipt "$PAYLOAD" >/dev/null

echo "✅ SIGNED"
echo "payload: $PAYLOAD"
echo "sig:     $SIG"
