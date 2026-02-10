#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: scripts/verify_halo_envelope_json.sh <event_json> <envelope_json> <allowed_signers_file>" >&2
  exit 2
fi

EVENT="$1"
ENV="$2"
ALLOWED="$3"

# ---- SET THIS IF YOUR VERIFIER HAS A DIFFERENT NAME/PATH ----
VERIFIER="${VERIFIER:-scripts/verify_halo_envelope.sh}"
# ------------------------------------------------------------

if [[ ! -f "$VERIFIER" ]]; then
  echo "ERROR: verifier not found at: $VERIFIER" >&2
  echo "Fix: edit scripts/verify_halo_envelope_json.sh and set VERIFIER= to your real verifier path." >&2
  exit 2
fi

# Run verifier and capture output + exit code
set +e
OUT="$("$VERIFIER" "$EVENT" "$ENV" "$ALLOWED" 2>&1)"
RC=$?
set -e

python3 - <<PY
import hashlib, json, datetime, re

out = """$OUT"""

def has(s: str) -> bool:
    return s in out

# Heuristics based on your verifier's human output
schema = "PASS" if (has("✅ SCHEMAS OK") or has("SCHEMAS OK")) else "FAIL"
canon  = "PASS" if (has("✅ EVENT HASH OK") or has("EVENT HASH OK") or has("CANONICAL HASH OK")) else "FAIL"
sig    = "PASS" if (has("✅ SIGNATURE VERIFIED") or has("SIGNATURE VERIFIED")) else "FAIL"

# signer authorization signals
if ("SIGNER NOT ALLOWED" in out) or ("NOT AUTHORIZED" in out) or ("unauthorized" in out.lower()):
    auth = "FAIL"
else:
    # if signature fails, authorization is effectively fail
    auth = "PASS" if sig == "PASS" else "FAIL"

status = "PASS" if ($RC == 0) else "FAIL"

# receipt_id: stable traceability hash of the EVENT file bytes
try:
    b = open("$EVENT","rb").read()
    receipt_id = hashlib.sha256(b).hexdigest()
except Exception:
    receipt_id = None

failure_reason = None
expected_hash = None
actual_hash = None
schema_errors = None
signer_identity = None
allowed_signers_version = None

# failure reason: first ❌ line if present
m = re.search(r"^❌.*$", out, re.M)
if m:
    failure_reason = m.group(0)

# expected/actual hash if your script prints them
m1 = re.search(r"expected:\s*([a-f0-9]{64})", out, re.I)
m2 = re.search(r"actual:\s*([a-f0-9]{64})", out, re.I)
if m1: expected_hash = m1.group(1)
if m2: actual_hash = m2.group(1)

# schema errors: include bounded excerpt if schema fails
if schema == "FAIL":
    lines = out.splitlines()
    schema_errors = lines[:40] if lines else None

result = {
  "status": status,
  "timestamp": datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat(),
  "receipt_id": receipt_id,
  "checks": {
    "schema": schema,
    "canonical_hash": canon,
    "signature": sig,
    "signer_authorized": auth
  },
  "details": {
    "failure_reason": failure_reason,
    "schema_errors": schema_errors,
    "expected_hash": expected_hash,
    "actual_hash": actual_hash,
    "signer_identity": signer_identity,
    "allowed_signers_version": allowed_signers_version
  }
}

print(json.dumps(result, indent=2))
raise SystemExit(0 if $RC == 0 else 1)
PY
