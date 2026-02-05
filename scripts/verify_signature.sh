#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: scripts/verify_signature.sh <receipt_json> <signer_id> <allowed_signers_file>"
  echo "Example: scripts/verify_signature.sh examples/receipts/receipt.sample.json halo-signer keys/allowed_signers"
  exit 2
fi

RECEIPT="$1"
SIGNER_ID="$2"
ALLOWED="$3"

PAYLOAD="${RECEIPT%.json}.payload"
SIG="${PAYLOAD}.sig"

# Recompute payload and verify signature matches it
python3 scripts/receipt_payload.py "$RECEIPT" > "$PAYLOAD.tmp"

ssh-keygen -Y verify -f "$ALLOWED" -I "$SIGNER_ID" -n halo-receipt -s "$SIG" < "$PAYLOAD.tmp" >/dev/null

rm -f "$PAYLOAD.tmp"
echo "✅ SIGNATURE VERIFIED"
