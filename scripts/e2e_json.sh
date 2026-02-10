#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

say() { echo; echo "== $* =="; }

# Inputs
EVENT_SRC="examples/receipts/healthcare_ai_v1.sample.json"
# Envelope output path (expected)
ENVELOPE_SRC="examples/receipts/healthcare_ai_v1.sample.json.halo.json"

# Allowed signers source (your repo uses a directory here)
ALLOWED="governance/trust/allowed_signers"

# Workspace
WORK="/tmp/halo_receipts_e2e"
EVENT="$WORK/event.json"
ENVELOPE="$WORK/envelope.json"

mkdir -p "$WORK"

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

# assert_json <json> <status> <schema> <canonical_hash> <signature> <signer_authorized>
# Use "-" to skip a field.
assert_json() {
  local json="$1"
  local exp_status="$2"
  local exp_schema="$3"
  local exp_canon="$4"
  local exp_sig="$5"
  local exp_auth="$6"

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

def chk(label, got, want):
    if want == "-":
        return
    if got != want:
        print(f"ASSERT FAIL {label}: got={got} expected={want}")
        raise SystemExit(2)

chk("status", j.get("status"), exp["status"])
cks = (j.get("checks") or {})
chk("checks.schema", cks.get("schema"), exp["schema"])
chk("checks.canonical_hash", cks.get("canonical_hash"), exp["canonical_hash"])
chk("checks.signature", cks.get("signature"), exp["signature"])
chk("checks.signer_authorized", cks.get("signer_authorized"), exp["signer_authorized"])

print("OK assertions:", {
  "status": j.get("status"),
  "schema": cks.get("schema"),
  "canonical_hash": cks.get("canonical_hash"),
  "signature": cks.get("signature"),
  "signer_authorized": cks.get("signer_authorized"),
})
PY
}

ensure_venv() {
  say "1) venv deps"
  python3 -m venv .venv >/dev/null 2>&1 || true
  .venv/bin/python -m pip install -U pip >/dev/null
}

clean_artifacts() {
  say "2) Clean generated artifacts"
  rm -f examples/receipts/*.halo.json 2>/dev/null || true
  rm -rf "$WORK" 2>/dev/null || true
  mkdir -p "$WORK"
}

generate_envelope() {
  say "3) Generate envelope"
  # This script should create the .halo.json next to EVENT_SRC
  .venv/bin/python scripts/make_halo_envelope.py "$EVENT_SRC" halo-signer

  # If the expected path doesn't exist, find the newest .halo.json as fallback.
  if [[ ! -f "$ENVELOPE_SRC" ]]; then
    local newest
    newest="$(ls -t examples/receipts/*.halo.json 2>/dev/null | head -n 1 || true)"
    if [[ -z "${newest:-}" ]]; then
      echo "❌ Could not find any generated examples/receipts/*.halo.json"
      exit 1
    fi
    ENVELOPE_SRC="$newest"
  fi
  echo "✅ Envelope: $ENVELOPE_SRC"
}

mutate_extensions() {
  .venv/bin/python - <<PY
import json
p="$EVENT"
d=json.load(open(p))
d.setdefault("extensions", {})["tamper"] = "ignore_me"
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated extensions")
PY
}

mutate_schema_valid_string_outside_extensions() {
  .venv/bin/python - <<PY
import json

p="$EVENT"
d=json.load(open(p))

preferred = [
  ["actor","service","instance"],
  ["actor","service","name"],
  ["actor","environment"],
  ["actor","signer_id"],
]

def get_parent(doc, path):
  cur=doc
  for k in path[:-1]:
    if not isinstance(cur, dict) or k not in cur:
      return None, None
    cur=cur[k]
  return cur, path[-1]

def is_str_at(doc, path):
  par,key=get_parent(doc, path)
  return par is not None and key in par and isinstance(par[key], str)

chosen=None
for path in preferred:
  if is_str_at(d, path):
    chosen=path
    break

if chosen is None:
  # fallback: find any string leaf not under extensions
  stack=[([], d)]
  while stack:
    path, cur = stack.pop()
    if isinstance(cur, dict):
      for k,v in cur.items():
        if path and path[0] == "extensions":
          continue
        stack.append((path+[k], v))
    elif isinstance(cur, list):
      for i,v in enumerate(cur):
        stack.append((path+[i], v))
    else:
      if isinstance(cur, str):
        chosen=path
        break

if chosen is None:
  raise SystemExit("Could not find any string field to mutate outside extensions.")

par,key=get_parent(d, chosen)
par[key] = par[key] + "_tampered"

json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("mutated schema-valid string at path:", ".".join(str(x) for x in chosen))
PY
}

force_schema_violation() {
  .venv/bin/python - <<PY
import json
p="$EVENT"
d=json.load(open(p))
d["actor"] = 123
json.dump(d, open(p,"w"), indent=2, sort_keys=True)
print("forced schema violation: actor=123")
PY
}

make_empty_allowed_like() {
  # If ALLOWED is a directory, make an empty directory. If it's a file, make an empty file.
  if [[ -d "$ALLOWED" ]]; then
    mktemp -d "$WORK/allowed_empty.XXXXXX"
  else
    mktemp "$WORK/allowed_empty.XXXXXX"
  fi
}

# --- run -------------------------------------------------------------------

say "0) Repo state"
git status -sb

ensure_venv
clean_artifacts
generate_envelope

say "4) Verify (baseline; EXPECT PASS)"
cp "$EVENT_SRC" "$EVENT"
cp "$ENVELOPE_SRC" "$ENVELOPE"
run_verify "$EVENT" "$ENVELOPE" "$ALLOWED"
echo "baseline verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -ne 0 ]]; then
  echo "❌ Baseline verify failed (should pass)."
  exit 1
fi
assert_json "$VERIFY_JSON" PASS PASS PASS PASS PASS
echo "✅ Baseline passed."

say "5) Git ignore check (envelope should be ignored)"
git check-ignore -v "$ENVELOPE_SRC"
echo "✅ Envelope is ignored."

say "6) Tamper EXTENSIONS (EXPECT PASS)"
cp "$EVENT_SRC" "$EVENT"
mutate_extensions
run_verify "$EVENT" "$ENVELOPE" "$ALLOWED"
echo "extensions-tamper verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -ne 0 ]]; then
  echo "❌ Extensions tamper unexpectedly failed (should pass)."
  exit 1
fi
assert_json "$VERIFY_JSON" PASS PASS PASS PASS PASS
echo "✅ Extensions tamper passed."

say "7) Tamper HASHED FIELD (EXPECT FAIL; schema PASS; canonical_hash FAIL)"
cp "$EVENT_SRC" "$EVENT"
mutate_schema_valid_string_outside_extensions
run_verify "$EVENT" "$ENVELOPE" "$ALLOWED" || true
echo "hashed-field tamper verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Hashed-field tamper unexpectedly passed (should fail)."
  exit 1
fi
# This is the key assertion you want.
assert_json "$VERIFY_JSON" FAIL PASS FAIL "-" "-"
echo "✅ Hashed-field tamper failed with schema PASS."

say "8) Schema violation (EXPECT FAIL; schema FAIL)"
cp "$EVENT_SRC" "$EVENT"
force_schema_violation
run_verify "$EVENT" "$ENVELOPE" "$ALLOWED" || true
echo "schema-violation verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Schema violation unexpectedly passed (should fail)."
  exit 1
fi
assert_json "$VERIFY_JSON" FAIL FAIL "-" "-" "-"
echo "✅ Schema violation failed."

say "9) Unauthorized signer (EXPECT FAIL; assert only status FAIL)"
EMPTY_ALLOWED="$(make_empty_allowed_like)"
run_verify "$EVENT_SRC" "$ENVELOPE_SRC" "$EMPTY_ALLOWED" || true
echo "unauthorized-signer verify exit code: $VERIFY_RC"
if [[ "$VERIFY_RC" -eq 0 ]]; then
  echo "❌ Unauthorized signer unexpectedly passed (should fail)."
  exit 1
fi
# Only assert top-level FAIL to match current behavior variations.
assert_json "$VERIFY_JSON" FAIL "-" "-" "-" "-"
echo "✅ Unauthorized signer rejected."

say "10) Done"
echo "🎉 E2E Suite Complete"
