#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== 0) Repo state =="
git checkout main >/dev/null
git pull --ff-only
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
.venv/bin/python scripts/make_halo_envelope.py examples/receipts/healthcare_ai_v1.sample.json halo-signer

echo
echo "== 4) Verify (baseline; EXPECT PASS) =="
set +e
scripts/verify_halo_envelope.sh \
  examples/receipts/healthcare_ai_v1.sample.json \
  examples/receipts/healthcare_ai_v1.sample.json.halo.json \
  governance/trust/allowed_signers
BASE_RC=$?
set -e
echo "baseline verify exit code: $BASE_RC"
if [[ "$BASE_RC" -ne 0 ]]; then
  echo "❌ Baseline verification failed (should pass)."
  exit 1
fi
echo "✅ Baseline passed."

echo
echo "== 5) Git ignore check (generated envelope should be ignored) =="
git status --porcelain=v1
git check-ignore -v examples/receipts/healthcare_ai_v1.sample.json.halo.json || true

echo
echo "== 6) Tamper EXTENSIONS (EXPECT PASS) =="
TMPDIR="$(mktemp -d)"
EVENT="$TMPDIR/halo_event.json"
ENV="$TMPDIR/halo_env.json"
cp examples/receipts/healthcare_ai_v1.sample.json "$EVENT"
cp examples/receipts/healthcare_ai_v1.sample.json.halo.json "$ENV"

.venv/bin/python - <<PY
import json
p="$EVENT"
d=json.load(open(p))
d["extensions"] = d.get("extensions", {})
d["extensions"]["tamper_test"] = "allowed_metadata_change"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
PY

set +e
scripts/verify_halo_envelope.sh "$EVENT" "$ENV" governance/trust/allowed_signers
EXT_RC=$?
set -e
echo "extensions-tamper verify exit code: $EXT_RC"
if [[ "$EXT_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper failed (but extensions are excluded from hashing, so it should pass)."
  exit 1
fi
echo "✅ Extensions tamper passed (expected)."

echo
echo "== 7) Tamper HASHED FIELD (EXPECT FAIL) =="
.venv/bin/python - <<PY
import json
p="$EVENT"
d=json.load(open(p))

def mutate(obj):
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
            if isinstance(v, str) and v:
                obj[k] = v + "_tampered"
                return True
            if isinstance(v, (dict, list)):
                if mutate(v):
                    return True
    elif isinstance(obj, list):
        for item in obj:
            if mutate(item):
                return True
    return False

ok = mutate(d)
if not ok:
    raise SystemExit("Could not find a safe hashed field to mutate (outside extensions).")

json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated a hashed field (outside extensions)")
PY

set +e
scripts/verify_halo_envelope.sh "$EVENT" "$ENV" governance/trust/allowed_signers
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
