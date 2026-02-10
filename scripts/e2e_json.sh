#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVENT_SRC="examples/receipts/healthcare_ai_v1.sample.json"
ENV_SRC="examples/receipts/healthcare_ai_v1.sample.json.halo.json"
ALLOWED="governance/trust/allowed_signers"

say() { echo; echo "== $* =="; }

# Run verifier and capture JSON (stdout) while preserving exit code
run_verify() {
  local ev="$1"; local env="$2"; local allowed="$3"
  local out rc
  set +e
  out="$(scripts/verify_halo_envelope_json.sh "$ev" "$env" "$allowed")"
  rc=$?
  set -e
  echo "$out"
  return $rc
}

# Assert JSON fields. Use "-" to skip asserting a particular check.
assert_json() {
  local json="$1"
  local exp_status="$2"
  local exp_schema="$3"
  local exp_canon="$4"
  local exp_sig="$5"
  local exp_auth="$6"

  python3 - "$json" "$exp_status" "$exp_schema" "$exp_canon" "$exp_sig" "$exp_auth" <<'PY'
import json, sys
j = json.loads(sys.argv[1])
exp = {
  "status": sys.argv[2],
  "schema": sys.argv[3],
  "canonical_hash": sys.argv[4],
  "signature": sys.argv[5],
  "signer_authorized": sys.argv[6],
}
def chk(key, expected):
  if expected == "-":
    return
  got = j.get("checks", {}).get(key) if key != "status" else j.get("status")
  if got != expected:
    raise SystemExit(f"ASSERT FAIL {key}: got={got} expected={expected}\nFULL={j}")

chk("status", exp["status"])
chk("schema", exp["schema"])
chk("canonical_hash", exp["canonical_hash"])
chk("signature", exp["signature"])
chk("signer_authorized", exp["signer_authorized"])
print("OK assertions:", exp)
PY
}

say "0) Repo state"
git status -sb

say "1) venv deps (idempotent)"
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema >/dev/null

say "2) Clean generated artifacts"
rm -f examples/receipts/*.halo.json examples/receipts/*.payload examples/receipts/*.payload.sig 2>/dev/null || true

say "3) Generate envelope"
.venv/bin/python scripts/make_halo_envelope.py "$EVENT_SRC" halo-signer

say "4) Verify (baseline; EXPECT PASS)"
json="$(run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED")"
BASE_RC=$?
echo "$json"
echo "baseline verify exit code: $BASE_RC"
if [[ "$BASE_RC" -ne 0 ]]; then
  echo "❌ Baseline verification failed."
  exit 1
fi
assert_json "$json" PASS PASS PASS PASS PASS
echo "✅ Baseline passed (JSON asserted)."

say "5) Git ignore check (generated envelope should be ignored)"
git check-ignore -v "$ENV_SRC" || { echo "❌ Expected $ENV_SRC to be ignored by git"; exit 1; }
echo "✅ Envelope is ignored (expected)."

# Work on temp copies so repo stays clean
EVENT="/tmp/halo_event.json"
ENV="/tmp/halo_env.json"
cp "$EVENT_SRC" "$EVENT"
cp "$ENV_SRC" "$ENV"

say "6) Tamper EXTENSIONS (EXPECT PASS)"
python3 - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))
d.setdefault("extensions", {})
d["extensions"]["tamper_test"] = "this_should_NOT_break_verification"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated extensions")
PY

json="$(run_verify "$EVENT" "$ENV" "$ALLOWED")"
EXT_RC=$?
echo "$json"
echo "extensions-tamper verify exit code: $EXT_RC"
if [[ "$EXT_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper unexpectedly failed (should pass)."
  exit 1
fi
assert_json "$json" PASS PASS PASS PASS PASS
echo "✅ Extensions tamper passed (JSON asserted)."

say "7) Tamper HASHED FIELD (EXPECT FAIL)"
python3 - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))

def mutate_string(obj):
    if isinstance(obj, dict):
        for k in list(obj.keys()):
            if k == "extensions":
                continue
            v = obj[k]
            if isinstance(v, str) and v:
                obj[k] = v + "_tampered"
                return True
            if isinstance(v, (dict, list)) and mutate_string(v):
                return True
    elif isinstance(obj, list):
        for item in obj:
            if mutate_string(item):
                return True
    return False

ok = mutate_string(d)
if not ok:
    raise SystemExit("Could not find a string field to mutate outside extensions.")
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated a hashed string field (outside extensions)")
PY

json="$(run_verify "$EVENT" "$ENV" "$ALLOWED")"
HASH_RC=$?
echo "$json"
echo "hashed-field tamper verify exit code: $HASH_RC"
if [[ "$HASH_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi
# Expect schema still OK; canonical hash/signature should fail. Auth may be FAIL too depending on verifier flow, so we don’t hard-pin it.
assert_json "$json" FAIL PASS FAIL FAIL "-"
echo "✅ Hashed-field tamper failed (JSON asserted)."

say "8) Schema violation (EXPECT FAIL; schema FAIL)"
BAD="/tmp/halo_bad_schema.json"
cp "$EVENT_SRC" "$BAD"
python3 - <<'PY'
import json
p="/tmp/halo_bad_schema.json"
# Write a list instead of an object -> should violate any object-based schema
json.dump([], open(p,"w"))
print("wrote schema-violating JSON (top-level list)")
PY

json="$(run_verify "$BAD" "$ENV" "$ALLOWED")"
SCHEMA_RC=$?
echo "$json"
echo "schema-violation verify exit code: $SCHEMA_RC"
if [[ "$SCHEMA_RC" -eq 0 ]]; then
  echo "❌ Schema violation unexpectedly passed (should fail)."
  exit 1
fi
assert_json "$json" FAIL FAIL "-" "-" "-"
echo "✅ Schema violation failed (JSON asserted)."

say "9) Determinism (EXPECT identical core fields; timestamp may differ)"
j1="$(run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED")"
j2="$(run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED")"

python3 - "$j1" "$j2" <<'PY'
import json, sys
A=json.loads(sys.argv[1]); B=json.loads(sys.argv[2])
for k in ("status","receipt_id","checks","details"):
    if A.get(k)!=B.get(k):
        raise SystemExit(f"NON-DETERMINISTIC {k}\nA={A.get(k)}\nB={B.get(k)}")
print("OK determinism: status/receipt_id/checks/details identical")
PY

echo "✅ Determinism check passed."

echo
echo "🎉 E2E JSON OK: baseline PASS, extensions PASS, hashed-field FAIL, schema FAIL, determinism OK."
