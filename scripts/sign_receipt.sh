#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/sign_receipt.sh <receipt_json>"
  exit 2
fi

RECEIPT="$1"
PAYLOAD="${RECEIPT%.json}.payload"
SIG="${PAYLOAD}.sig"

SIGNING_KEY="$HOME/.ssh/halo_receipts"

if [[ ! -f "$SIGNING_KEY" ]]; then
  echo "❌ Missing signing key: $SIGNING_KEY"
  exit 2
fi

rm -f "$PAYLOAD" "$SIG"

python3 scripts/receipt_payload.py "$RECEIPT" > "$PAYLOAD"

ssh-keygen -Y sign -f "$SIGNING_KEY" -n halo-receipt "$PAYLOAD" >/dev/null

echo "✅ SIGNED"

