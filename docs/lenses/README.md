# HALO Interpretive Lenses

HALO-RECEIPTS produces cryptographic receipts that assert only byte existence
and signature validity.

HALO itself does not interpret meaning, intent, safety, legality, or trust.

This directory defines standard interpretive lenses that downstream systems,
organizations, auditors, and reviewers may apply to a HALO receipt.

Each lens answers a different question using the same underlying receipt.

---

## Available Lenses

- **Security**
  - Can this artifact be proven unchanged since signing?
  - `SECURITY.md`

- **Governance**
  - Does this artifact meet organizational or policy requirements?
  - `GOVERNANCE.md`

- **Evidentiary / Legal**
  - Can this artifact support evidentiary or audit use cases?
  - `EVIDENCE.md`

- **Operations**
  - How does this artifact fit into operational workflows?
  - `OPERATIONS.md`

- **Non-Goals**
  - What HALO explicitly does *not* claim or attempt
  - `NON_GOALS.md`

---

## Separation of Concerns

A single HALO receipt may be evaluated through multiple lenses simultaneously.

No lens changes the receipt.
No lens is authoritative over another.
No lens is embedded into the receipt itself.

Interpretation is external by design.
