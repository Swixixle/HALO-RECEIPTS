# HALO Interpretive Lenses

HALO-RECEIPTS produces cryptographic receipts that assert only byte existence and signature validity.

All interpretation is intentionally external.

This document defines the standard interpretive lenses that downstream systems, organizations, auditors, and courts may apply to HALO receipts without altering the underlying cryptographic artifact.

A single receipt may support multiple interpretations simultaneously without modification.

---

## Why Lenses Exist

HALO-RECEIPTS deliberately refuses to embed meaning, intent, authorship, or context into the receipt itself.

This separation ensures that:
- Cryptographic integrity remains stable over time
- Interpretive standards may evolve without invalidating historical receipts
- Multiple stakeholders can evaluate the same artifact independently

Lenses formalize interpretation without contaminating the cryptographic core.

---

## Available Lenses

- **[Security](lenses/SECURITY.md)**  
  Determines whether a receipt is cryptographically valid, unaltered, and signed by an approved key.

- **[Governance](lenses/GOVERNANCE.md)**  
  Evaluates whether receipt creation and usage align with organizational policy, authority, and process.

- **[Evidentiary / Legal](lenses/EVIDENCE.md)**  
  Assesses admissibility, chain-of-custody, and probative value without asserting truth or intent.

- **[Operations](lenses/OPERATIONS.md)**  
  Supports audits, incident response, and post-mortem analysis using verified artifacts.

- **[Non-Goals](lenses/NON_GOALS.md)**  
  Explicitly documents interpretations and guarantees HALO-RECEIPTS does not provide.

---

## Stability Guarantee

Interpretive lenses may change.

Receipts do not.
