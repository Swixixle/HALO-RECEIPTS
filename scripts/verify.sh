EXPECTED_BYTES=$(python3 - <<PY
import json
r=json.load(open("$RECEIPT","r",encoding="utf-8"))
print(int(r["subject"]["byte_length"]))
PY
)

ACTUAL_BYTES=$(wc -c < "$TRANSCRIPT" | tr -d ' ')

if [[ "$ACTUAL_BYTES" != "$EXPECTED_BYTES" ]]; then
  echo "❌ NOT VERIFIED (byte_length mismatch)"
  echo "expected bytes: $EXPECTED_BYTES"
  echo "actual bytes:   $ACTUAL_BYTES"
  exit 1
fi





#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: scripts/verify.sh <transcript_file> <receipt_json>"
  exit 2
fi

TRANSCRIPT="$1"
RECEIPT="$2"

# Read expected hash + algorithm from receipt
ALG=$(python3 - <<PY
import json
r=json.load(open("$RECEIPT","r",encoding="utf-8"))
print(r["content_hash"]["alg"])
PY
)

EXPECTED=$(python3 - <<PY
import json
r=json.load(open("$RECEIPT","r",encoding="utf-8"))
print(r["content_hash"]["value"])
PY
)

# Compute actual hash (v0.1 assumes sha256)
if [[ "$ALG" != "sha256" ]]; then
  echo "Unsupported alg in receipt: $ALG (only sha256 sucd ~/Workspace/HALO-RECEIPTS
pwd
/Users/alexmaksimovich/Workspace/HALO-RECEIPTS
pported in v0.1)"
  exit 3
fi

ACTUAL=$(shasum -a 256 "$TRANSCRIPT" | awk '{print $1}')

if [[ "$ACTUAL" == "$EXPECTED" ]]; then
  echo "✅ VERIFIED"
  echo "hash: $ACTUAL"
  exit 0
else
  echo "❌ NOT VERIFIED"
  echo "expected: $EXPECTED"
  echo "actual:   $ACTUAL"
  exit 1
fi
