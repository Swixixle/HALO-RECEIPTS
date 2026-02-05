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

if [[ ! -f "$SIG" ]]; then
  echo "❌ Missing signature file: $SIG"
  echo "Run: scripts/sign_receipt.sh $RECEIPT"
  exit 2
fi

# Recompute payload deterministically from receipt
python3 scripts/receipt_payload.py "$RECEIPT" > "$PAYLOAD"

ssh-keygen -Y verify -f "$ALLOWED" -I "$SIGNER_ID" -n halo-receipt -s "$SIG" < "$PAYLOAD" >/dev/null

echo "✅ SIGNATURE VERIFIED"
