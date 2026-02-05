# HALO Receipt Schema (v0.1)

## Purpose
A HALO Receipt is a portable, tamper-evident proof artifact for an AI conversation (or any transcript).
It allows any verifier to confirm that a presented transcript matches the originally receipted content.

## Non-goals
- Does not prove the content is correct, safe, or compliant.
- Does not prove who authored the transcript.
- Does not prevent copying/sharing; only detects alteration.
- Does not require trusting the issuer, platform, or presenter during verification.

## Receipt object (top-level fields)
The receipt is a single JSON object.

### Required
- `schema_version` (string): e.g. `"0.1"`
- `created_at` (string): ISO-8601 timestamp
- `content_hash` (object)
  - `alg` (string): hash algorithm identifier (e.g. `"sha256"`)
  - `value` (string): hex/base64 hash of the canonicalized content
- `canonicalization` (object)
  - `name` (string): canonicalization profile identifier
  - `rules` (array[string]): human-readable list of rules used
- `subject` (object)
  - `type` (string): `"conversation"` | `"document"` | `"bundle"`
  - `content_type` (string): e.g. `"text/plain"` or `"application/json"`
  - `byte_length` (integer): length of canonical bytes hashed

### Recommended
- `model` (object)  (if AI convo)
  - `provider` (string)
  - `name` (string)
  - `version` (string|optional)
- `session` (object)
  - `session_id` (string|optional)
  - `turn_index` (integer|optional)
- `inputs` (array[object]) (minimal provenance)
  - each: `{ "role": "user|assistant|system|tool", "hash_ref": "…" }`  (optional scaffolding for future)
- `issuer` (object)
  - `name` (string)
  - `key_id` (string|optional)

### Optional (for stronger receipts later)
- `signature` (object)
  - `alg` (string)
  - `key_id` (string)
  - `value` (string)

## Canonicalization (v0.1 default)
Goal: ensure the same transcript always hashes the same way.

Baseline rules:
1. UTF-8 encoding
2. Normalize line endings to `\n`
3. Trim trailing whitespace per line
4. Ensure exactly one final newline at EOF
5. No BOM

## Verification procedure (human)
To verify:
1. Canonicalize the presented transcript using the receipt’s `canonicalization`.
2. Hash canonical bytes using `content_hash.alg`.
3. Compare to `content_hash.value`.
4. Match = verified. Mismatch = altered.

## Filename guidance
Recommended: `halo-receipt_<YYYYMMDD>_<shortHash>.json`

## Security notes
- Hash-only receipts detect edits but do not prove who issued them.
- Signatures add issuer authenticity but are not required for v0.1.
cat > examples/receipts/receipt.sample.json << 'EOF'
{
  "schema_version": "0.1",
  "created_at": "2026-02-05T18:00:00Z",
  "content_hash": {
    "alg": "sha256",
    "value": "REPLACE_ME_WITH_REAL_HASH"
  },
  "canonicalization": {
    "name": "halo-text-v0.1",
    "rules": [
      "utf-8 encoding",
      "normalize line endings to \\n",
      "trim trailing whitespace per line",
      "ensure exactly one final newline at EOF",
      "no BOM"
    ]
  },
  "subject": {
    "type": "conversation",
    "content_type": "text/plain",
    "byte_length": 0
  },
  "issuer": {
    "name": "HALO Receipts (sample)"
  }
}
EOF
mkdir -p examples/transcripts
cat > examples/transcripts/conversation.txt << 'EOF'
User: What is the capital of France?
Assistant: The capital of France is Paris.
EOF
wc -c examples/transcripts/conversation.txt
shasum -a 256 examples/transcripts/conversation.txt
HASH=$(shasum -a 256 examples/transcripts/conversation.txt | awk '{print $1}')
BYTES=$(wc -c < examples/transcripts/conversation.txt | tr -d ' ')

python3 - <<PY
import json
p="examples/receipts/receipt.sample.json"
with open(p,"r",encoding="utf-8") as f:
    r=json.load(f)
r["content_hash"]["value"]= "${HASH}"
r["subject"]["byte_length"]= int("${BYTES}")
with open(p,"w",encoding="utf-8") as f:
    json.dump(r,f,indent=2)
    f.write("\n")
print("Wrote hash + byte_length into receipt.sample.json")
PY
cat examples/receipts/receipt.sample.json
