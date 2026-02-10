#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EVENT_SRC="examples/receipts/healthcare_ai_v1.sample.json"
ENV_SRC="examples/receipts/healthcare_ai_v1.sample.json.halo.json"
ALLOWED="governance/trust/allowed_signers"

say() { echo; echo "== $* =="; }

# Run JSON verifier and stash JSON in VERIFY_JSON
run_verify() {
  local ev="$1"; local env="$2"; local allowed="$3"
  set +e
  VERIFY_JSON="$(scripts/verify_halo_envelope_json.sh "$ev" "$env" "$allowed")"
  RC=$?
  set -e
  echo "$VERIFY_JSON"
  return $RC
}

# Assert JSON contract fields
assert_json() {
  local json="$1"; shift
  local expect_status="$1"; shift
  local expect_schema="$1"; shift
  local expect_canon="$1"; shift
  local expect_sig="$1"; shift
  local expect_auth="$1"; shift

  python3 - "$json" "$expect_status" "$expect_schema" "$expect_canon" "$expect_sig" "$expect_auth" <<'PY'
import json, sys
j=json.loads(sys.argv[1])
exp={"status":sys.argv[2],"schema":sys.argv[3],"canonical_hash":sys.argv[4],"signature":sys.argv[5],"signer_authorized":sys.argv[6]}
def fail(msg):
    raise SystemExit(msg + "\nFULL=" + json.dumps(j, indent=2, sort_keys=True))
if j.get("status") != exp["status"]:
    fail(f"ASSERT FAIL status: got={j.get('status')} expected={exp['status']}")
cks=j.get("checks",{})
for k in ("schema","canonical_hash","signature","signer_authorized"):
    if cks.get(k) != exp[k]:
        fail(f"ASSERT FAIL checks.{k}: got={cks.get(k)} expected={exp[k]}")
print("OK assertions:", exp)
PY
}

say "0) Repo state"
git status -sb || true

say "1) venv deps (idempotent)"
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema >/dev/null

say "2) Clean generated artifacts"
rm -f examples/receipts/*.halo.json examples/receipts/*.payload examples/receipts/*.payload.sig 2>/dev/null || true

say "3) Generate envelope"
.venv/bin/python scripts/make_halo_envelope.py "$EVENT_SRC" halo-signer

say "4) Verify (baseline; EXPECT PASS)"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED"
BASE_RC=$?
echo "baseline verify exit code: $BASE_RC"
if [[ "$BASE_RC" -ne 0 ]]; then
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
python3 - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))
d.setdefault("extensions", {})
d["extensions"]["tamper_test"] = "this_should_NOT_break_verification"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated extensions")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED"
EXT_RC=$?
echo "extensions-tamper verify exit code: $EXT_RC"
if [[ "$EXT_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper unexpectedly failed (should pass)."
  exit 1
fi
assert_json "$VERIFY_JSON" PASS PASS PASS PASS PASS
echo "✅ Extensions tamper passed (JSON asserted)."

say "7) Tamper HASHED FIELD (EXPECT FAIL; schema must stay PASS)"
python3 - <<'PY'
import json, copy
from pathlib import Path

event_path="/tmp/halo_event.json"
evt=json.load(open(event_path))

def iter_string_paths(obj, path=()):
    # skip extensions (not hashed)
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

def find_validating_schema(event_obj):
    try:
        import jsonschema
    except Exception:
        return None, None
    roots = ["receipts","examples","governance"]
    candidates=[]
    for r in roots:
        p=Path(r)
        if p.exists():
            candidates += list(p.rglob("*schema*.json"))
    for sp in candidates:
        try:
            schema=json.load(open(sp))
            jsonschema.validate(event_obj, schema)
            return schema, str(sp)
        except Exception:
            pass
    return None, None

schema, schema_path = find_validating_schema(evt)

if schema is None:
    # No schema found: just mutate first non-extensions string
    for path in iter_string_paths(evt):
        cand=copy.deepcopy(evt)
        cur=cand
        for p in path[:-1]:
            cur=cur[p]
        cur[path[-1]] = cur[path[-1]] + "_tampered"
        json.dump(cand, open(event_path,"w"), indent=2, sort_keys=True)
        print("mutated (no schema available) at path:", ".".join(map(str,path)))
        raise SystemExit(0)
    raise SystemExit("Could not find a string field to mutate outside extensions.")
else:
    import jsonschema
    for path in iter_string_paths(evt):
        cand=copy.deepcopy(evt)
        cur=cand
        for p in path[:-1]:
            cur=cur[p]
        old=cur[path[-1]]
        if not isinstance(old,str) or not old:
            continue
        cur[path[-1]] = old + "_tampered"
        try:
            jsonschema.validate(cand, schema)
        except Exception:
            continue
        json.dump(cand, open(event_path,"w"), indent=2, sort_keys=True)
        print("mutated schema-valid string field at path:", ".".join(map(str,path)))
        print("schema used:", schema_path)
        raise SystemExit(0)
    raise SystemExit("Could not find a schema-valid string field to mutate outside extensions.")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED"
HASH_RC=$?
echo "hashed-field tamper verify exit code: $HASH_RC"
if [[ "$HASH_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi

python3 - "$VERIFY_JSON" <<'PY'
import json, sys
j=json.loads(sys.argv[1])
assert j.get("status")=="FAIL", j
assert j.get("checks",{}).get("schema")=="PASS", j
assert j.get("checks",{}).get("canonical_hash")=="FAIL", j
print("OK hashed-field tamper: schema PASS, canonical_hash FAIL")
PY

echo "✅ Hashed-field tamper failed via hash mismatch (JSON asserted)."

say "8) Schema violation (EXPECT FAIL; schema FAIL)"
python3 - <<'PY'
import json
p="/tmp/halo_event.json"
d=json.load(open(p))
d["__schema_breaker__"] = object()  # not JSON-serializable; force a clean schema/parse fail by writing a string instead
# fallback: write a guaranteed schema-breaking extra field as a string
d["__schema_breaker__"] = "this_field_should_break_schema_if additionalProperties=false"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("wrote schema breaker field")
PY

run_verify "$EVENT" "$ENV" "$ALLOWED"
SCHEMA_RC=$?
echo "schema-violation verify exit code: $SCHEMA_RC"
if [[ "$SCHEMA_RC" -eq 0 ]]; then
  echo "❌ Schema violation unexpectedly passed (should fail)."
  exit 1
fi

python3 - "$VERIFY_JSON" <<'PY'
import json, sys
j=json.loads(sys.argv[1])
assert j.get("status")=="FAIL", j
assert j.get("checks",{}).get("schema")=="FAIL", j
print("OK schema violation: schema FAIL")
PY

echo "✅ Schema violation failed (JSON asserted)."

say "9) Determinism (EXPECT identical core fields; timestamp may differ)"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED"
j1="$VERIFY_JSON"
run_verify "$EVENT_SRC" "$ENV_SRC" "$ALLOWED"
j2="$VERIFY_JSON"

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
echo "🎉 E2E JSON OK: baseline PASS, extensions PASS, hashed-field FAIL (schema PASS), schema FAIL, determinism OK."
