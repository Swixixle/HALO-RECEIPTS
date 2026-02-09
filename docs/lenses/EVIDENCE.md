# Evidence Lens

**Question:**
Can this artifact be relied upon as durable, verifiable evidence that specific bytes existed and were signed?

---

## What This Lens Treats as Evidence

- A byte-exact payload derived deterministically from a receipt
- A cryptographic signature over that payload
- A verifiable signing identity (via allowed signers)
- A reproducible verification process

Together, these form an **evidentiary primitive**.

---

## Assertions This Lens Can Support

- The payload existed in exactly this form
- The payload has not been altered since signing
- The payload was signed by a specific cryptographic key
- The signature is verifiable at any later time
- Independent parties can reproduce verification

---

## Assertions Explicitly Not Made

- That the contents are true
- That the contents are accurate
- That the contents are complete
- That the contents reflect intent or understanding
- That the signer endorsed or approved the contents
- That the artifact has legal standing in any jurisdiction

Evidence ≠ Truth  
Evidence ≠ Meaning  
Evidence ≠ Authority

---

## Evidentiary Properties

HALO receipts are designed to be:

- **Immutable** — any byte change breaks verification
- **Portable** — no central service required to verify
- **Context-free** — meaning is not embedded
- **Re-evaluable** — evidence can be reinterpreted later

This allows evidence to survive:
- Organizational changes
- Policy shifts
- Legal reinterpretation
- Disputes over meaning or intent

---

## Evidence vs Testimony

HALO produces **evidence**, not testimony.

- Evidence is mechanically verifiable
- Testimony requires trust, interpretation, or belief

HALO intentionally avoids testimonial claims.

---

## Design Boundary

HALO does not:
- Rank evidence strength
- Attach legal weight
- Resolve disputes
- Decide admissibility
- Replace human judgment

It preserves evidence so judgment can occur without ambiguity.
