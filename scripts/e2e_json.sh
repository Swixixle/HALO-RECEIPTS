#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVENT_SRC="examples/receipts/healthcare_ai_v1.sample.json"
ENV_SRC="examples/receipts/healthcare_ai_v1.sample.json.halo.json"
ALLOWED="governance/trust/allowed_signers"

say() { echo; echo "== $* =="; }

# Globals set by run_verify
VERIFY_JSON=""
VERIFY_RC=0

run_verify() {
  local ev="$1"
  local env="$2"
  local allowed="$3"

  set +e
  local out
  out="$(scripts/verify_halo_envelope_json.sh "$ev" "$env" "$allowed")"
  local rc=$?
  set -e

  VERIFY_JSON="$out"
  VERIFY_RC=$rc

  echo "$out"
  return $rc
}

# assert_json <json> <status> <schema> <canon> <sig> <auth>
# Use "-" for "don't care"
assert_json() {
  local json="$1"; shift
  local exp_status="$1"; shift
  local exp_schema="$1"; shift
  local exp_canon="$1"; shift
  local exp_sig="$1"; shift
  local exp_auth="$1"; shift

  .venv/bin/python - "$json" "$exp_status" "$exp_schema" "$exp_canon" "$exp_sig" "$exp_auth" <<'PY'
import json, sys

j = json.loads(sys.argv[1])
exp = {
  "status": sys.argv[2],
  "schema": sys.argv[3],
  "canonical_hash": sys.argv[4],
  "signature": sys.argv[5],
  "signer_authorized": sys.argv[6],
}

def chk(path, got, want):
    if want == "-":
        return
    if got != want:
        print(f"ASSERT FAIL {path}: got={got} expected={want}")
        print("FULL=" + repr(j))
        raise SystemExit(2)

chk("status", j.get("status"), exp["status"])
cks = j.get("checks", {}) or {}

chk("checks.schema", cks.get("schema"), exp["schema"])
chk("checks.canonical_hash", cks.get("canonical_hash"), exp["canonical_hash"])
chk("checks.signature", cks.get("signature"), exp["signature"])
chk("checks.signer_authorized", cks.get("signer_authorized"), exp["signer_authorized"])

print("OK assertions:", exp)
PY
}

say "0) Repo state"
git status -sb

say "1) venv deps (idempotent)"
python3 -m venv .venv >/dev/null 2>&1 || true
.venv/bin/python -m pip install -U pip jsonschema >/dev/null

say "2) Clean generated artifacts"
rm -f examples/receipts/*.halo.json examples/receipts/*.payload examples/receipts/*.payload.sig 2>/dev/null || true

say "3) Generate envelope"
.venv/bin/python scripts/make_halo_envelope.py "$EVENT_SRC" halo-signer

say "4) Verify (baseline; EXPECT PASS)"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED"
echo "baseline verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -ne 0 ]]; then
  echo "❌ Baseline verification failed."
  exit 1
fi
assert_json "$VERIFY_JSON" PASS PASS PASS PASS PASS
echo "✅ Baseline passed (JSON asserted)."

say "5) Git ignore check (generated envelope should be ignored)"
git check-ignore -v "$ENV_SRC" || { echo "❌ Expected $ENV_SRC to be ignored by git"; exit 1; }
echo "✅ Envelope is ignored (expected)."

# Work on temp copies so repo stays clean
EVENT="/tmp/halo_event.json"
ENV="/tmp/halo_env.json"
cp "$EVENT_SRC" "$EVENT"
cp "$ENV_SRC" "$ENV"

say "6) Tamper EXTENSIONS (EXPECT PASS; extensions excluded)"
.venv/bin/python - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))
d.setdefault("extensions", {})
d["extensions"]["tamper_test"] = "this_should_NOT_break_verification"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated extensions")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED"
echo "extensions-tamper verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper unexpectedly failed (should pass)."
  exit 1
fi
assert_json "$VERIFY_JSON" PASS PASS PASS PASS PASS
echo "✅ Extensions tamper passed (JSON asserted)."

say "7) Tamper HASHED FIELD (EXPECT FAIL; schema must stay PASS)"
# Use event-specific schema if it exists, else fallback.
BASE="$(basename "$EVENT_SRC")"
BASE="${BASE%.sample.json}"

SCHEMA_PATH="receipts/schema/receipt.${BASE}.schema.json"
if [[ ! -f "$SCHEMA_PATH" ]]; then
  SCHEMA_PATH="receipts/schema/receipt.schema.json"
fi
echo "schema selected: $SCHEMA_PATH"

.venv/bin/python - "$EVENT" "$SCHEMA_PATH" <<'PY'
import json, sys
from copy import deepcopy
from jsonschema import validate
from jsonschema.exceptions import ValidationError

event_path = sys.argv[1]
schema_path = sys.argv[2]

evt = json.load(open(event_path))
schema = json.load(open(schema_path))

# Collect candidate paths to string leaves, excluding anything under "extensions"
paths = []

def walk(obj, cur):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if cur == [] and k == "extensions":
                # exclude whole subtree
                continue
            if k == "extensions":
                # also exclude nested extensions if any
                continue
            walk(v, cur + [k])
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            walk(v, cur + [i])
    elif isinstance(obj, str) and obj != "":
        paths.append(cur)

def set_at(root, path, value):
    cur = root
    for p in path[:-1]:
        cur = cur[p]
    cur[path[-1]] = value

walk(evt, [])

def is_valid(candidate):
    try:
        validate(instance=candidate, schema=schema)
        return True
    except ValidationError:
        return False

# Try mutating each string field until schema still validates.
for p in paths:
    candidate = deepcopy(evt)
    # mutate string
    cur = candidate
    for step in p:
        cur = cur[step]
    set_at(candidate, p, cur + "_tampered")

    if is_valid(candidate):
        json.dump(candidate, open(event_path, "w"), indent=2, sort_keys=True)
        printable = ".".join(str(x) for x in p)
        print("mutated schema-valid string at path:", printable)
        raise SystemExit(0)

raise SystemExit("Could not find a schema-valid string field to mutate outside extensions.")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED"
echo "hashed-field tamper verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi

# Only require: status FAIL, schema PASS, canonical_hash FAIL.
# Signature/auth can be PASS or FAIL depending on verifier flow; don't pin them here.
assert_json "$VERIFY_JSON" FAIL PASS FAIL "-" "-"
echo "✅ Hashed-field tamper failed with schema PASS (JSON asserted)."

say "8) Schema violation (EXPECT FAIL; schema FAIL)"
cp "$EVENT_SRC" "$EVENT"

.venv/bin/python - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))
d["actor"] = 123
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("forced schema violation: actor=123")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED"
echo "schema-violation verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Schema violation unexpectedly passed (should fail)."
  exit 1
fi
assert_json "$VERIFY_JSON" FAIL FAIL "-" "-" "-"
echo "✅ Schema violation failed (JSON asserted)."

say "9) Unauthorized signer (EXPECT FAIL; signer_authorized FAIL)"
EMPTY_ALLOWED="/tmp/allowed_signers_empty"
: > "$EMPTY_ALLOWED"

run_verify "$EVENT_SRC" "$ENV_SRC" "$EMPTY_ALLOWED"
echo "unauthorized-signer verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Unauthorized signer unexpectedly passed (should fail)."
  exit 1
fi
assert_json "$VERIFY_JSON" FAIL "-" "-" "-" FAIL
echo "✅ Unauthorized signer rejected (JSON asserted)."

say "10) Determinism (EXPECT identical core fields; timestamp may differ)"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED" || true
j1="$VERIFY_JSON"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED" || true
j2="$VERIFY_JSON"

.venv/bin/python - "$j1" "$j2" <<'PY'
import json, sys
A=json.loads(sys.argv[1]); B=json.loads(sys.argv[2])
for k in ("status","receipt_id","checks","details"):
    if A.get(k)!=B.get(k):
        raise SystemExit(f"NON-DETERMINISTIC {k}\nA={A.get(k)}\nB={B.get(k)}")
print("OK determinism: status/receipt_id/checks/details identical")
PY

echo "✅ Determinism check passed."

echo
echo "🎉 E2E JSON OK: baseline PASS, extensions PASS, hashed-field FAIL (schema PASS), schema FAIL, auth FAIL, determinism OK."
