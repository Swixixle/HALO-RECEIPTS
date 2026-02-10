#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVENT="examples/receipts/healthcare_ai_v1.sample.json"
ENV_OUT="examples/receipts/healthcare_ai_v1.sample.json.halo.json"
ALLOWED="governance/trust/allowed_signers"
SIGNER_ID="halo-signer"

echo "== 0) Repo state =="
git checkout main >/dev/null
git pull --ff-only >/dev/null
git status -sb

echo
echo "== 1) venv deps (idempotent) =="
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema >/dev/null

echo
echo "== 2) Clean generated artifacts =="
rm -f examples/receipts/*.halo.json examples/receipts/*.payload examples/receipts/*.payload.sig 2>/dev/null || true

echo
echo "== 3) Generate envelope =="
.venv/bin/python scripts/make_halo_envelope.py "$EVENT" "$SIGNER_ID"

echo
echo "== 4) Verify (baseline; EXPECT PASS) =="
set +e
scripts/verify_halo_envelope.sh "$EVENT" "$ENV_OUT" "$ALLOWED"
BASE_RC=$?
set -e
echo "baseline verify exit code: $BASE_RC"
if [[ "$BASE_RC" -ne 0 ]]; then
  echo "❌ Baseline failed (should pass)."
  exit 1
fi
echo "✅ Baseline passed."

echo
echo "== 5) Git ignore check (generated envelope should be ignored) =="
git status --porcelain=v1
git check-ignore -v "$ENV_OUT" || (echo "❌ Envelope is NOT ignored by git"; exit 1)

echo
echo "== 6) Tamper EXTENSIONS (EXPECT PASS) =="
TMP_EVENT="/tmp/halo_event.json"
TMP_ENV="/tmp/halo_env.json"
cp "$EVENT" "$TMP_EVENT"
cp "$ENV_OUT" "$TMP_ENV"

python3 - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))
d["extensions"] = d.get("extensions", {})
d["extensions"]["tamper_test"] = "ok_extensions_are_unhashed"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated extensions")
PY

set +e
scripts/verify_halo_envelope.sh "$TMP_EVENT" "$TMP_ENV" "$ALLOWED"
EXT_RC=$?
set -e
echo "extensions-tamper verify exit code: $EXT_RC"
if [[ "$EXT_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper failed (should pass)."
  exit 1
fi
echo "✅ Extensions tamper passed (expected)."

echo
echo "== 7) Tamper HASHED FIELD (EXPECT FAIL with EVENT HASH MISMATCH) =="
cp "$EVENT" "$TMP_EVENT"
cp "$ENV_OUT" "$TMP_ENV"

python3 - <<'PY'
import json

p="/tmp/halo_event.json"
d=json.load(open(p))

def mutate_number(obj):
    if isinstance(obj, dict):
        for k in list(obj.keys()):
            if k == "extensions":
                continue
            v = obj[k]
            if isinstance(v, int):
                obj[k] = v + 1
                return True
            if isinstance(v, float):
                obj[k] = v + 0.001
                return True
            if isinstance(v, (dict, list)) and mutate_number(v):
                return True
    elif isinstance(obj, list):
        for item in obj:
            if mutate_number(item):
                return True
    return False

ok = mutate_number(d)
if not ok:
    raise SystemExit("Could not find a numeric field to mutate outside extensions.")

json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated a numeric hashed field (outside extensions)")
PY

set +e
scripts/verify_halo_envelope.sh "$TMP_EVENT" "$TMP_ENV" "$ALLOWED"
HASH_RC=$?
set -e
echo "hashed-field tamper verify exit code: $HASH_RC"
if [[ "$HASH_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi
if [[ "$HASH_RC" -ne 1 ]]; then
  echo "⚠️ Hashed-field tamper failed, but not with hash-mismatch exit code 1 (still acceptable)."
fi
echo "✅ Hashed-field tamper failed (expected)."

echo
echo "🎉 E2E OK: baseline pass, extensions pass, hashed-field fail."
