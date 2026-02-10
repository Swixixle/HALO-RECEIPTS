#!/usr/bin/env bash
set -euo pipefail

EVENT_PATH="${1:-}"
ENV_PATH="${2:-}"
ALLOWED_PATH="${3:-}"

if [[ -z "$EVENT_PATH" || -z "$ENV_PATH" || -z "$ALLOWED_PATH" ]]; then
  echo "Usage: $0 <event.json> <envelope.halo.json> <allowed_signers>"
  exit 2
fi

VERIFIER="${VERIFIER:-scripts/verify_halo_envelope.sh}"

# Run the canonical verifier and capture all output
set +e
OUT="$("$VERIFIER" "$EVENT_PATH" "$ENV_PATH" "$ALLOWED_PATH" 2>&1)"
RC=$?
set -e

python3 - "$EVENT_PATH" "$ALLOWED_PATH" "$RC" "$OUT" <<'PY'
import sys, json, re, hashlib, datetime

event_path = sys.argv[1]
allowed_path = sys.argv[2]
rc = int(sys.argv[3])
out = sys.argv[4]

# Timestamp (timezone-aware UTC)
timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

# Defaults
status = "PASS" if rc == 0 else "FAIL"
schema = "PASS"
canon = "PASS"
sig = "PASS"
auth = "PASS"

failure_reason = None
schema_errors = None
expected_hash = None
actual_hash = None

# Deterministic signer identity from Event
signer_identity = None
try:
    evt = json.load(open(event_path))
    signer_identity = (evt.get("actor") or {}).get("signer_id")
except Exception:
    signer_identity = None

# Allowed signers version (sha256 of allowlist bytes)
allowed_signers_version = None
try:
    ab = open(allowed_path, "rb").read()
    allowed_signers_version = hashlib.sha256(ab).hexdigest()
except Exception:
    allowed_signers_version = None

# A receipt_id that is stable per Event bytes (simple + deterministic)
receipt_id = None
try:
    eb = open(event_path, "rb").read()
    receipt_id = hashlib.sha256(eb).hexdigest()
except Exception:
    receipt_id = None

# --- Parse verifier output for PASS/FAIL signals ---
# Baseline scripts print:
# ✅ SCHEMAS OK
# ✅ EVENT HASH OK
# ✅ SIGNATURE VERIFIED
# etc.
# Failures often include:
# ❌ INVALID EVENT (schema): ...
# ❌ EVENT HASH MISMATCH
# ❌ SIGNATURE INVALID
# ❌ UNAUTHORIZED SIGNER

def has(pat: str) -> bool:
    return re.search(pat, out, re.I) is not None

# Schema

# Only mark schema FAIL on explicit schema failure indicators.
# Do NOT treat generic "❌" or the mere word "schema" as a schema failure.
if has(r"INVALID EVENT \(schema\)|SCHEMA(S)? (FAILED|FAIL)"):
    schema = "FAIL"

# Canonical hash / event hash
if has(r"EVENT HASH MISMATCH|CANON(ICAL)?( HASH)? (MISMATCH|FAIL)"):
    canon = "FAIL"

# Signature
if has(r"SIGNATURE (INVALID|FAIL)|SIGNATURE VERIFY FAILED"):
    sig = "FAIL"

# Auth / allowed signers
if has(r"UNAUTHORIZED SIGNER|SIGNER NOT ALLOWED|NOT IN ALLOWED SIGNERS|allowed signers.*(fail|invalid)"):
    auth = "FAIL"

# If any check is FAIL, status is FAIL
if "FAIL" in (schema, canon, sig, auth):
    status = "FAIL"

# Failure reason + details extraction
# Prefer explicit schema failure line
m = re.search(r"(?:❌\s*)?INVALID EVENT \(schema\):.*", out)
if m:
    failure_reason = m.group(0).strip()
    # Provide a compact schema_errors list (first ~20 non-empty lines after the schema error)
    lines = out.splitlines()
    idx = next((i for i,l in enumerate(lines) if "INVALID EVENT (schema)" in l), None)
    if idx is not None:
        chunk = [l for l in lines[idx:idx+30] if l.strip()][:20]
        schema_errors = chunk

# Event hash mismatch: try to find expected/actual hashes if printed anywhere
if has(r"EVENT HASH MISMATCH"):
    failure_reason = failure_reason or "❌ EVENT HASH MISMATCH"
    m1 = re.search(r"expected[^0-9a-f]*([0-9a-f]{64})", out, re.I)
    m2 = re.search(r"actual[^0-9a-f]*([0-9a-f]{64})", out, re.I)
    if m1: expected_hash = m1.group(1)
    if m2: actual_hash = m2.group(1)

# Signature fail reason (if no schema/hash reason)
if sig == "FAIL" and failure_reason is None:
    if has(r"UNAUTHORIZED SIGNER"):
        failure_reason = "❌ UNAUTHORIZED SIGNER"
    else:
        failure_reason = "❌ SIGNATURE VERIFICATION FAILED"

result = {
  "status": status,
  "timestamp": timestamp,
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
raise SystemExit(0 if rc == 0 else 1)
PY
