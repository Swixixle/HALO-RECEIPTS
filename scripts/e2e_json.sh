#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVENT_SRC="examples/receipts/healthcare_ai_v1.sample.json"
ENV_SRC="examples/receipts/healthcare_ai_v1.sample.json.halo.json"
ALLOWED="governance/trust/allowed_signers"

say() { echo; echo "== $* =="; }

say "0) Repo state"
git checkout main >/dev/null
git pull --ff-only >/dev/null
git status -sb

say "1) venv deps (idempotent)"
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema >/dev/null

say "2) Clean generated artifacts"
rm -f examples/receipts/*.halo.json examples/receipts/*.payload examples/receipts/*.payload.sig 2>/dev/null || true

say "3) Generate envelope"
.venv/bin/python scripts/make_halo_envelope.py "$EVENT_SRC" halo-signer

say "4) Verify (baseline; EXPECT PASS)"
set +e
scripts/verify_halo_envelope_json.sh "$EVENT_SRC" "$ENV_SRC" "$ALLOWED"
BASE_RC=$?
set -e
echo "baseline verify exit code: $BASE_RC"
if [[ "$BASE_RC" -ne 0 ]]; then
  echo "❌ Baseline verification failed."
  exit 1
fi
echo "✅ Baseline passed."

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

json=20 20 12 61 79 80 81 701 33 98 100 204 250 395 398 399 400run_verify "" "" "")
EXT_RC=0
echo "extensions-tamper verify exit code: "
if [[ "" -ne 0 ]]; then
  echo "❌ Extensions tamper unexpectedly failed (should pass)."
  echo ""
  exit 1
fi
assert_json "" PASS PASS PASS PASS PASS
echo "✅ Extensions tamper passed (JSON asserted)."

say "7) Tamper HASHED FIELD (EXPECT FAIL; prefer EVENT HASH MISMATCH)"
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

set +e
scripts/verify_halo_envelope_json.sh "$EVENT" "$ENV" "$ALLOWED"
HASH_RC=$?
set -e
echo "hashed-field tamper verify exit code: $HASH_RC"
if [[ "$HASH_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi
echo "✅ Hashed-field tamper failed (expected)."

echo
echo "🎉 E2E OK: baseline pass, extensions pass, hashed-field fail."
