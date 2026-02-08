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
# Basic schema validation (matches receipt_payload.py expectations)
python3 - <<'PY' "$RECEIPT"
import json, sys, re
from pathlib import Path

p = Path(sys.argv[1])
r = json.loads(p.read_text(encoding="utf-8"))

def die(msg):
    print(f"❌ INVALID RECEIPT: {msg}")
    sys.exit(2)

# Required top-level fields used by receipt_payload.py
for k in ["content_hash", "subject"]:
    if k not in r:
        die(f"missing field '{k}'")

ch = r["content_hash"]
if not isinstance(ch, dict):
    die("content_hash must be an object")
if ch.get("alg") != "sha256":
    die("content_hash.alg must be 'sha256'")
val = ch.get("value")
if not isinstance(val, str) or not re.fullmatch(r"[0-9a-f]{64}", val):
    die("content_hash.value must be 64 lowercase hex chars")

sub = r["subject"]
if not isinstance(sub, dict):
    die("subject must be an object")
bl = sub.get("byte_length")
if bl is None:
    die("subject.byte_length missing")
try:
    int(bl)
except Exception:
    die("subject.byte_length must be an integer")

# issuer is optional in receipt_payload.py, but if present must be object
iss = r.get("issuer")
if iss is not None and not isinstance(iss, dict):
    die("issuer must be an object if present")

print("✅ RECEIPT SHAPE OK")
PY

# Recompute payload deterministically from receipt
python3 scripts/receipt_payload.py "$RECEIPT" > "$PAYLOAD"

ssh-keygen -Y verify -f "$ALLOWED" -I "$SIGNER_ID" -n halo-receipt -s "$SIG" < "$PAYLOAD" >/dev/null

echo "✅ SIGNATURE VERIFIED"
