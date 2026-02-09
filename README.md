# HALO-RECEIPTS

HALO-RECEIPTS is a minimal cryptographic receipt system for **byte-exact audit artifacts**.

Given a receipt JSON, HALO:
1) validates it against a JSON Schema,
2) derives a deterministic canonical payload (`.payload`),
3) signs that payload using OpenSSH (`ssh-keygen -Y sign`),
4) verifies it later against an **allowed signers** file (`ssh-keygen -Y verify`).

If any signed byte changes, verification fails.

---

## Why this exists

Modern systems (especially AI systems) produce decisions that need to be **provable after the fact**: what happened, who did it, what inputs/outputs were involved, and what policy/version governed the action.

HALO-RECEIPTS provides a simple primitive:
- **deterministic payloads**
- **standard signing**
- **machine-verifiable audit trails**

…without needing a database, network, or proprietary crypto.

---

## Core guarantees

- Deterministic payload derivation (byte-exact)
- JSON Schema validation before signing/verifying
- OpenSSH signing + verification (`ssh-keygen -Y`)
- Scriptable verification suitable for CI/audit pipelines
- “If bytes change, signature breaks” semantics

---

## Prerequisites

- OpenSSH ≥ 8.2 (for `ssh-keygen -Y`)
- Python 3
- `jsonschema` (Python package)

---

## Quick demo (fresh clone → verified receipt)

```bash
cd ~/HALO-RECEIPTS

python3 -m venv .venv
source .venv/bin/activate
pip install jsonschema

RECEIPT="examples/receipts/healthcare_ai_v1.sample.json"
SIGNER_ID="halo-signer"
ALLOWED_SIGNERS="governance/trust/allowed_signers"

# 1) derive canonical payload
python3 scripts/receipt_payload.py "$RECEIPT" > "${RECEIPT%.json}.payload"
wc -c "${RECEIPT%.json}.payload"

# 2) sign (writes ${RECEIPT%.json}.payload.sig)
./scripts/sign_receipt.sh "$RECEIPT"

# 3) verify (should PASS)
./scripts/verify_signature.sh "$RECEIPT" "$SIGNER_ID" "$ALLOWED_SIGNERS" \
  && echo "OK: signature verified" \
  || echo "FAIL: signature did not verify"

