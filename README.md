# HALO-RECEIPTS

HALO-RECEIPTS is a minimal cryptographic receipt system.

It produces a deterministic, byte-exact payload from a receipt JSON file and
uses OpenSSH signatures to sign and verify that payload.

If the bytes change, the signature breaks.

---

## Core Guarantees

- Deterministic payload derivation (byte-exact)
- SSH-based signing and verification (OpenSSH `ssh-keygen -Y`)
- JSON Schema validation of receipts
- Human-readable audit artifacts
- Scriptable, non-interactive verification with exit codes

---

## Status

🚧 Early / scaffold stage

- [x] Deterministic payload derivation
- [x] SSH signature signing & verification
- [x] JSON Schema validation
- [ ] Multi-signer enrollment (future)
- [ ] Machine identity distribution (future)

---

## Minimal end-to-end example

HALO-RECEIPTS is intentionally small and deterministic. It performs:

1. Derive a canonical, byte-exact payload from a receipt JSON
2. Sign that payload with an SSH private key
3. Verify that signature later against an allowed signers file

### Prerequisites

- OpenSSH ≥ 8.2 (for `ssh-keygen -Y`)
- Python 3
- `jsonschema` (for schema validation)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install jsonschema
