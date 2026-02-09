# HALO-RECEIPTS — Architecture Overview

## Design Principle

HALO-RECEIPTS is architected around a single invariant:

If any signed byte changes, verification must fail.

Everything else exists only to support that invariant.

The system is intentionally minimal, deterministic, and hostile to ambiguity.

---

## End-to-End Flow

Input Artifact
→ Canonicalization
→ Deterministic Payload Construction
→ Cryptographic Signing (SSH)
→ Receipt + Detached Signature
→ Independent Verification

This flow is linear, explicit, and non-branching.

---

## Core Components

### 1. Receipt Schema

The receipt schema defines the allowed structure of a receipt and is enforced prior to any signing or verification.

Only schema-valid receipts are eligible for payload construction.

This prevents underspecified, ambiguous, or malformed inputs from entering the signing pipeline.

---

### 2. Canonical Payload Builder

The canonical payload builder produces a byte-exact payload from receipt fields.

Ordering, formatting, encoding, and field inclusion are deterministic and environment-independent.

No implicit defaults, locale behavior, or runtime variation is permitted.

The same receipt must always produce the same payload bytes.

---

### 3. Cryptographic Signing Layer

Signing uses standard SSH keys and tooling.

No custom cryptographic primitives are introduced.

Signatures are detached from the payload and stored as explicit artifacts.

This allows verification using existing, well-understood SSH mechanisms.

---

### 4. Verification Pipeline

Verification proceeds in a strict sequence:

1. Schema validation of the receipt
2. Deterministic reconstruction of the payload
3. Cryptographic verification of the signature

Failure at any stage halts verification immediately.

There is no partial success state.

---

## Trust Boundaries

The system enforces hard boundaries between what it guarantees and what it explicitly refuses to guarantee.

### In Scope (Trusted by Design)

• Local signing key  
• Canonicalization rules  
• Receipt schema  
• Payload construction logic  
• Signature verification logic  

### Out of Scope (Explicitly Untrusted)

• Content meaning  
• Author intent  
• Artifact provenance  
• Truthfulness of claims  
• Legal, ethical, or policy interpretation  
• Downstream use of receipts  

HALO-RECEIPTS does not cross these boundaries.

---

## Threat Model Alignment

The architecture assumes adversarial conditions, including:

• Modification of receipt fields  
• Replay or substitution of signed artifacts  
• Partial system compromise outside the signing key  

The architecture does not attempt to:

• Detect false statements  
• Prevent misuse of signed artifacts  
• Resolve disputes over interpretation  

Those concerns belong outside this system.

---

## Failure Modes (By Design)

HALO-RECEIPTS prefers hard failure over permissive behavior.

Examples include:

• Modified receipt → verification failure  
• Missing signature → verification failure  
• Schema mismatch → verification failure  

Silent degradation or ambiguous success is considered a defect.

---

## Extensibility Constraints

Extensions are permitted only if they do not:

• Alter canonicalization rules  
• Weaken verification semantics  
• Introduce semantic interpretation  

Acceptable extensions include:

• Schema-versioned metadata fields  
• Alternate key distribution mechanisms  
• Integration adapters  

Rejected extensions include:

• Meaning inference  
• Policy enforcement  
• Truth scoring  
• Governance logic  

---

## Architectural Non-Goals

HALO-RECEIPTS is not:

• A ledger  
• A database  
• A compliance engine  
• A trust oracle  
• A governance authority  

It is a cryptographic primitive, not a system of belief.

---

## Summary

HALO-RECEIPTS is intentionally boring at the core.

Its power comes from refusing to do more than:

• Construct bytes deterministically  
• Sign them cryptographically  
• Verify them independently  

This restraint is what makes it safe to build upon.
