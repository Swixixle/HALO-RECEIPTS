#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: scripts/verify_halo_envelope.sh <event_json> <envelope_json> <allowed_signers_file>"
  exit 2
fi

EVENT_JSON="$1"
ENVELOPE_JSON="$2"
ALLOWED="$3"

PYTHON="python3"
if [[ -x ".venv/bin/python" ]]; then
  PYTHON=".venv/bin/python"
fi

[[ -f "$EVENT_JSON" ]] || { echo "❌ Missing event: $EVENT_JSON"; exit 2; }
[[ -f "$ENVELOPE_JSON" ]] || { echo "❌ Missing envelope: $ENVELOPE_JSON"; exit 2; }
[[ -f "$ALLOWED" ]] || { echo "❌ Missing allowed signers: $ALLOWED"; exit 2; }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

PAYLOAD_BIN="$TMPDIR/payload.bin"
SIG_FILE="$TMPDIR/envelope.sig"

# Read signer_id + namespace from envelope
SIGNER_ID="$("$PYTHON" - <<'PY' "$ENVELOPE_JSON"
import json, sys
env = json.load(open(sys.argv[1], "r", encoding="utf-8"))
print(env["signer_id"])
PY
)"

NAMESPACE="$("$PYTHON" - <<'PY' "$ENVELOPE_JSON"
import json, sys
env = json.load(open(sys.argv[1], "r", encoding="utf-8"))
print(env.get("namespace") or "")
PY
)"

if [[ -z "$NAMESPACE" ]]; then
  echo "❌ Envelope missing namespace"
  exit 2
fi

"$PYTHON" - <<'PY' "$EVENT_JSON" "$ENVELOPE_JSON" "$PAYLOAD_BIN" "$SIG_FILE"
import json, sys, hashlib
from pathlib import Path
from jsonschema import validate

EVENT_JSON = Path(sys.argv[1])
ENVELOPE_JSON = Path(sys.argv[2])
PAYLOAD_BIN = Path(sys.argv[3])
SIG_FILE = Path(sys.argv[4])

def die(msg, code=2):
    print(f"❌ {msg}", file=sys.stderr)
    raise SystemExit(code)

# Load + schema-validate event
schema_path = Path("receipts/schema/receipt.schema.json")
if not schema_path.is_file():
    die(f"Missing schema file: {schema_path}", 2)

event = json.loads(EVENT_JSON.read_text(encoding="utf-8"))
schema = json.loads(schema_path.read_text(encoding="utf-8"))

try:
    validate(instance=event, schema=schema)
except Exception as e:
    die(f"INVALID EVENT (schema): {e}", 2)

print("✅ SCHEMAS OK")

env = json.loads(ENVELOPE_JSON.read_text(encoding="utf-8"))
for k in ("ces_version","event_hash","signer_id","timestamp_utc","signature","namespace"):
    if k not in env:
        die(f"Envelope missing: {k}", 2)

# Canonicalize event for hash (exclude extensions)
event_for_hash = dict(event) if isinstance(event, dict) else event
if isinstance(event_for_hash, dict) and "extensions" in event_for_hash:
    event_for_hash.pop("extensions", None)

event_bytes = json.dumps(event_for_hash, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
actual = hashlib.sha256(event_bytes).hexdigest()
expected = env["event_hash"]

if actual != expected:
    die(f"EVENT HASH MISMATCH\nexpected: {expected}\nactual:   {actual}", 1)

print("✅ EVENT HASH OK")

# Rebuild signature payload EXACTLY (NO trailing newline)
payload = (
    f'{env["ces_version"]}\n'
    f'{env["event_hash"]}\n'
    f'{env["signer_id"]}\n'
    f'{env["timestamp_utc"]}'
).encode("utf-8")
PAYLOAD_BIN.write_bytes(payload)

sig = env["signature"]
if not sig.endswith("\n"):
    sig += "\n"
SIG_FILE.write_text(sig, encoding="utf-8")

print("✅ PAYLOAD+SIG READY")
PY

ssh-keygen -Y verify -f "$ALLOWED" -I "$SIGNER_ID" -n "$NAMESPACE" -s "$SIG_FILE" < "$PAYLOAD_BIN" >/dev/null
echo "✅ SIGNATURE VERIFIED"
