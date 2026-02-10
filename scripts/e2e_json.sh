#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVENT_SRC="examples/receipts/healthcare_ai_v1.sample.json"
ENV_SRC="examples/receipts/healthcare_ai_v1.sample.json.halo.json"
ALLOWED="governance/trust/allowed_signers"

say() { echo; echo "== $* =="; }

VERIFY_JSON=""
VERIFY_RC=0

run_verify() {
  local ev="$1" env="$2" allowed="$3"
  local out rc
  set +e
  out="$(scripts/verify_halo_envelope_json.sh "$ev" "$env" "$allowed")"
  rc=$?
  set -e
  VERIFY_JSON="$out"
  VERIFY_RC=$rc
  echo "$out"
  return $rc
}

# expected values: PASS/FAIL or "-" (wildcard)
assert_json() {
  local json="$1"
  local expect_status="$2"
  local expect_schema="$3"
  local expect_canon="$4"
  local expect_sig="$5"
  local expect_auth="$6"

  .venv/bin/python - "$json" "$expect_status" "$expect_schema" "$expect_canon" "$expect_sig" "$expect_auth" <<'PY'
import json, sys

j=json.loads(sys.argv[1])
exp_status, exp_schema, exp_canon, exp_sig, exp_auth = sys.argv[2:7]

def check(name, got, exp):
    if exp == "-":
        return
    if got != exp:
        raise SystemExit(f"ASSERT FAIL {name}: got={got} expected={exp}\nFULL={j}")

check("status", j.get("status"), exp_status)

cks = j.get("checks") or {}
check("checks.schema", cks.get("schema"), exp_schema)
check("checks.canonical_hash", cks.get("canonical_hash"), exp_canon)
check("checks.signature", cks.get("signature"), exp_sig)
check("checks.signer_authorized", cks.get("signer_authorized"), exp_auth)

print("OK assertions:", {
  "status": exp_status,
  "schema": exp_schema,
  "canonical_hash": exp_canon,
  "signature": exp_sig,
  "signer_authorized": exp_auth
})
PY
}

say "0) Repo state"
git checkout main >/dev/null 2>&1 || true
git pull --ff-only >/dev/null 2>&1 || true
git status -sb

say "1) venv deps (idempotent)"
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema >/dev/null

say "2) Clean generated artifacts"
rm -f examples/receipts/*.halo.json examples/receipts/*.payload examples/receipts/*.payload.sig 2>/dev/null || true

say "3) Generate envelope"
.venv/bin/python scripts/make_halo_envelope.py "$EVENT_SRC" halo-signer

say "4) Verify (baseline; EXPECT PASS)"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED" || true
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

run_verify "$EVENT" "$ENV" "$ALLOWED" || true
echo "extensions-tamper verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper unexpectedly failed (should pass)."
  exit 1
fi
assert_json "$VERIFY_JSON" PASS PASS PASS PASS PASS
echo "✅ Extensions tamper passed (JSON asserted)."

say "7) Tamper HASHED FIELD (EXPECT FAIL; schema must stay PASS)"
# Find a schema that validates the original event, then mutate a string leaf in a way that keeps schema valid.
.venv/bin/python - "$EVENT" <<'PY'
import json, sys
from copy import deepcopy
from pathlib import Path
import jsonschema

event_path=sys.argv[1]
evt=json.load(open(event_path))

# Candidate schemas in this repo (exclude venv metaschemas)
cands=[]
for p in Path("receipts/schema").glob("*.json"):
    if p.name.startswith("halo_") or "envelope" in p.name:
        continue
    cands.append(p)
# fallback: any schema-ish json in repo (still avoid .venv)
if not cands:
    for p in Path(".").rglob("*schema*.json"):
        if ".venv" in p.parts or "node_modules" in p.parts:
            continue
        cands.append(p)

schema=None
schema_path=None
for sp in cands:
    try:
        sj=json.load(open(sp))
        jsonschema.validate(evt, sj)
        schema=sj
        schema_path=str(sp)
        break
    except Exception:
        continue

if schema is None:
    raise SystemExit("Could not find a schema that validates the sample event. (Looked in receipts/schema and repo *schema*.json)")

print("schema selected:", schema_path)

def iter_string_paths(obj, path=()):
    # never mutate extensions
    if path and path[0] == "extensions":
        return
    if isinstance(obj, dict):
        for k,v in obj.items():
            yield from iter_string_paths(v, path+(k,))
    elif isinstance(obj, list):
        for i,v in enumerate(obj):
            yield from iter_string_paths(v, path+(i,))
    elif isinstance(obj, str) and obj:
        yield path

def get_subschema(s, path):
    cur=s
    for p in path:
        if not isinstance(cur, dict):
            return None
        if isinstance(p, int):
            items=cur.get("items")
            cur=items if isinstance(items, dict) else None
        else:
            props=cur.get("properties")
            cur=props.get(p) if isinstance(props, dict) else None
    return cur if isinstance(cur, dict) else None

def is_schema_safe_string(sub):
    if sub is None:
        return False
    # avoid common constraints that suffixing breaks
    if any(k in sub for k in ("enum","const","pattern","format")):
        return False
    t=sub.get("type")
    if t is not None and t != "string":
        return False
    return True

def within_maxlen(sub, val, suffix):
    ml=sub.get("maxLength")
    return True if ml is None else (len(val)+len(suffix) <= ml)

suffix="_tampered"

for path in iter_string_paths(evt):
    sub=get_subschema(schema, path)
    if not is_schema_safe_string(sub):
        continue

    cand=deepcopy(evt)
    cur=cand
    for p in path[:-1]:
        cur=cur[p]
    old=cur[path[-1]]
    if not isinstance(old, str) or not old:
        continue
    if not within_maxlen(sub, old, suffix):
        continue

    cur[path[-1]] = old + suffix

    try:
        jsonschema.validate(cand, schema)
    except Exception:
        continue

    json.dump(cand, open(event_path,"w"), indent=2, sort_keys=True)
    print("mutated schema-valid string at path:", ".".join(map(str, path)))
    raise SystemExit(0)

raise SystemExit("Could not find ANY schema-safe string field to mutate outside extensions.")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED" || true
echo "hashed-field tamper verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi
# auth can vary depending on verifier semantics when signature fails
assert_json "$VERIFY_JSON" FAIL PASS FAIL FAIL "-"
echo "✅ Hashed-field tamper failed with schema PASS (JSON asserted)."

say "8) Schema violation (EXPECT FAIL; schema FAIL)"
BAD="/tmp/halo_event_schemafail.json"
cp "$EVENT_SRC" "$BAD"
.venv/bin/python - <<'PY'
import json
p="/tmp/halo_event_schemafail.json"
d=json.load(open(p))
d["actor"] = 123  # force type error
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("forced schema violation: actor=123")
PY

run_verify "$BAD" "$ENV_SRC" "$ALLOWED" || true
echo "schema-violation verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Schema violation unexpectedly passed."
  exit 1
fi
assert_json "$VERIFY_JSON" FAIL FAIL "-" "-" "-"
echo "✅ Schema violation failed (JSON asserted)."

say "9) Unauthorized signer (EXPECT FAIL; signer_authorized FAIL)"
EMPTY_ALLOWED="/tmp/allowed_signers_empty"
: > "$EMPTY_ALLOWED"

run_verify "$EVENT_SRC" "$ENV_SRC" "$EMPTY_ALLOWED" || true
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
