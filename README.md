# HALO-RECEIPTS

HALO-RECEIPTS is a cryptographic audit infrastructure for producing verifiable, tamper-evident proof artifacts.

**Scope:** notarization + verification.  
**Non-scope:** data management, meaning/intent interpretation, scoring, AI judgments.

## Core objects

### 1) Event receipt (domain receipt)
A structured JSON event (example: `healthcare_ai_v1`) validated by schema and canonicalized deterministically.

- Canonicalization: UTF-8, lexicographic key sort, no insignificant whitespace.
- Hash: SHA-256 over canonical event bytes.

Schema(s):
- `receipts/schema/receipt.schema.json`
- `receipts/schema/receipt.healthcare_ai_v1.schema.json`

Example event:
- `examples/receipts/healthcare_ai_v1.sample.json`

### 2) HALO envelope (portable proof)
A standalone JSON envelope that proves:
- the event existed in a specific canonical form (via `event_hash`)
- a known signer attested to that hash (signature over a strict payload)

Envelope fields:
- `schema`: `halo_envelope_v1`
- `ces_version`
- `event_hash_alg`
- `event_hash`
- `signer_id`
- `timestamp_utc`
- `namespace` (OpenSSH signature namespace; must match exactly on verify)
- `signature` (OpenSSH signature block)

Envelope schema:
- `receipts/schema/halo_envelope_v1.schema.json`

Example envelope:
- `examples/receipts/healthcare_ai_v1.sample.json.halo.json`

## Quickstart

### Setup
Requires:
- Node.js
- Python + `jsonschema`
- OpenSSH (`ssh-keygen -Y sign/verify`)

Install Python deps into repo venv:
```bash
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema
