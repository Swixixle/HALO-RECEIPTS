# BOUNDARY

HALO-RECEIPTS is deliberately narrow.

This document defines what the system **is not**, and what it will **refuse to become**.

## What HALO-RECEIPTS Does

HALO-RECEIPTS records that specific bytes existed at a specific moment and were cryptographically signed by a known key.

It provides:
- Byte-exact canonicalization
- Cryptographic signatures
- Deterministic verification
- Tamper visibility

Nothing more.

## What HALO-RECEIPTS Explicitly Does NOT Do

HALO-RECEIPTS does **not**:

- Assert truth, accuracy, or correctness
- Infer intent, meaning, or authorship
- Judge legality, compliance, or ethics
- Interpret content semantics
- Perform attribution beyond cryptographic key identity
- Act as a source of authority or verdict
- Resolve disputes or contradictions
- Validate real-world events
- Provide guarantees about human behavior
- Prevent misuse of signed content

If a question cannot be answered by comparing bytes and signatures, it is out of scope.

## Non-Goals

The following are **non-goals**, even if technically feasible:

- Content validation
- Policy enforcement
- AI judgment or interpretation
- “Trust scores” or reputational signals
- Narrative reconstruction
- Moral, legal, or factual conclusions

These concerns belong to downstream systems.

## Boundary Enforcement

Requests to extend HALO-RECEIPTS beyond these boundaries should be treated as design violations, not feature requests.

The system’s integrity depends on its refusal to decide meaning.

## Design Principle

> This system exists to make modification visible, not to decide meaning.

Any change that weakens this principle is a regression.
