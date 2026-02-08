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

# JSON Schema validation (requires jsonschema installed in your active python env)
python3 - <<'PY' "$RECEIPT"
import json, sys
from pathlib import Path

receipt_path = Path(sys.argv[1])
schema_path = Path("receipts/schema/receipt.schema.json")

def die(msg, code=2):
    print(f"❌ INVALID RECEIPT: {msg}")
    sys.exit(code)

try:
    r = json.loads(receipt_path.read_text(encoding="utf-8"))
except Exception as e:
    die(f"failed to read JSON: {e}")

try:
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
except Exception as e:
    die(f"failed to read schema {schema_path}: {e}")

try:
    import jsonschema
except Exception:
    die("python module 'jsonschema' not installed. Activate venv and run: python -m pip install jsonschema")

try:
    jsonschema.validate(instance=r, schema=schema)
except jsonschema.ValidationError as e:
    die(str(e).splitlines()[0])

print("✅ SCHEMA OK")
PY

# Recompute payload deterministically from receipt
python3 scripts/receipt_payload.py "$RECEIPT" > "$PAYLOAD"

# Verify signature over payload
ssh-keygen -Y verify -f "$ALLOWED" -I "$SIGNER_ID" -n halo-receipt -s "$SIG" < "$PAYLOAD" >/dev/null

echo "✅ SIGNATURE VERIFIED"

