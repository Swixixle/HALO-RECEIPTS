# Flow Lens

This lens describes how information, responsibility, and certainty move through HALO-RECEIPTS.

It is not about control.
It is about containment.

---

## Core Flow Principle

HALO-RECEIPTS enforces a **one-way flow of certainty**:

Human intent → bytes → canonicalization → signature → verification

Once bytes are signed, meaning stops moving.

---

## Separation of Concerns

HALO-RECEIPTS intentionally separates:

- **Creation** (what was produced)
- **Assertion** (what someone claims about it)
- **Evidence** (what can be proven later)

Only the first is inside the system.
The others are downstream consumers.

---

## Where Meaning Stops

HALO-RECEIPTS draws a hard line:

> Meaning ends at the byte boundary.

After canonicalization:
- No interpretation is allowed
- No normalization is permitted
- No context is preserved
- No intent is inferred

The system becomes deaf by design.

---

## Temporal Flow

HALO-RECEIPTS is asymmetric in time.

- Creation happens once
- Verification can happen infinitely
- Verification does not require the creator
- Verification does not trust the verifier

Past existence is checked from the future without negotiation.

---

## Trust Direction

Trust flows **outward**, never inward.

- The verifier does not trust the issuer
- The system does not trust the environment
- The signature does not trust transport
- The receipt does not trust interpretation

Trust is replaced with mechanical proof.

---

## Failure as Signal

Breaks in flow are intentional signals, not errors to smooth over.

Examples:
- Byte mismatch → tampering or mis-derivation
- Unknown signer → governance failure
- Schema violation → invalid artifact

There is no recovery path inside the system.
Resolution happens outside it.

---

## Why This Matters

Most systems fail by letting meaning flow backward.

HALO-RECEIPTS prevents:
- Retroactive reinterpretation
- Context laundering
- Narrative drift
- Authority substitution

It freezes one fact:
**these bytes existed and were signed**.

Everything else is someone else’s problem.
