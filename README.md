# HALO-RECEIPTS

HALO-RECEIPTS is a **minimal cryptographic receipt system**.

It derives a deterministic, byte-exact payload from a receipt JSON, then uses
**OpenSSH signatures** (`ssh-keygen -Y`) to sign and verify that payload.

If the bytes change, the signature breaks.

> **Design intent:** cryptographic memory for byte-exact artifacts — not telemetry, not a database,
> and not a “truth engine.”

---

## Core Guarantees

HALO-RECEIPTS provides:

- **Deterministic payload derivation** (byte-exact)
- **SSH-based signing and verification** (OpenSSH `ssh-keygen -Y`)
- **JSON Schema validation** for receipts
- **Human-readable artifacts** (receipt JSON + signature + verifier output)
- **Scriptable, non-interactive verification** suitable for CI / incident review

---

## Non-Goals / Explicit Non-Claims

HALO-RECEIPTS does **not** claim to provide:

- Truth, correctness, intent, medical appropriateness, or clinical safety
- Identity beyond **possession/control of the signing key**
- Protection from key compromise or malicious authorized insiders
- Storage, indexing, search, retention, or audit UI (those are integrations on top)
- “HIPAA de-identified data” by default (see Privacy Posture below)

What it does claim is narrower and stronger:

> “These exact bytes existed and were signed by a specific key, and they still verify.”

---

## Status

🚧 Early / scaffold stage (intentionally small and deterministic)

- [x] Deterministic payload derivation
- [x] SSH signature signing & verification
- [x] JSON Schema validation
- [ ] Multi-signer enrollment (future)
- [ ] Machine identity distribution (future)
- [ ] Timestamp authority anchoring (future)
- [ ] Storage/query layer (future)

---

## Repository Layout

- `scripts/` — payload derivation, signing, verification helpers (shell + python)
- `receipts/schema/` — JSON Schema(s) for receipts
- `governance/` — trust store, policy scaffolds
- `docs/` — design notes (if present)
- `examples/` — sample receipts / demo artifacts (if present)
- `src/` — early code experiments / helpers (not a stable API yet)

---

## Minimal end-to-end example

HALO-RECEIPTS performs:

1. Derive a canonical, byte-exact payload from a receipt JSON
2. Sign that payload with an SSH private key
3. Verify the signature later against an **allowed signers** file

### Prerequisites

- OpenSSH ≥ 8.2 (for `ssh-keygen -Y`)
- Python 3
- `jsonschema` (for schema validation)

### Setup

```bash
# from repo root
python3 -m venv .venv
source .venv/bin/activate
pip install jsonschema

