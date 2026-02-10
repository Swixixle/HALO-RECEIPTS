# HALO-RECEIPTS

HALO-RECEIPTS is a cryptographic audit infrastructure for producing verifiable, tamper-evident proof artifacts.

**Scope:** notarization + verification.  
**Non-scope:** data management, meaning/intent interpretation, scoring, AI judgments.

## Lexicon (Core Objects)

- **Event**: the raw domain JSON (e.g., a healthcare AI decision record).
- **Canonical payload**: the deterministic UTF-8 bytes derived from the Event that are hashed.
- **Envelope**: the cryptographic wrapper (`.halo.json`) containing hash + signature + metadata.
- **Receipt**: the conceptual unit formed by **Event + Envelope**.

## Schemas & Examples

Event schema:
- `receipts/schema/receipt.schema.json`

Envelope schema:
- `receipts/schema/halo_envelope_v1.schema.json`

Example Event:
- `examples/receipts/healthcare_ai_v1.sample.json`

Example Envelope (generated, usually ignored by git):
- `examples/receipts/healthcare_ai_v1.sample.json.halo.json`

## Quickstart (Generate → Verify → Tamper)

### Setup
Requires:
- Node.js
- Python + `jsonschema`
- OpenSSH (`ssh-keygen -Y sign/verify`)

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -U pip jsonschema
