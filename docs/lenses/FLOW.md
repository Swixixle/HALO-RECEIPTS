# Flow Lens

This document describes the canonical flow of HALO-RECEIPTS from artifact creation to later verification.

This is not a workflow prescription.
It is a factual description of what happens.

---

## High-Level Flow

1. Bytes exist
2. Bytes are normalized
3. A deterministic payload is derived
4. The payload is signed
5. Signature and payload are stored
6. Verification occurs later, elsewhere

There are no callbacks, no upstream dependencies, and no required downstream consumers.

---

## Step 1: Artifact Exists

An artifact is produced by some external process.

Examples:
- A JSON document
- A policy file
- A prompt or model configuration
- A log snapshot
- A report or decision memo

HALO-RECEIPTS does not care **how** the artifact was produced.

---

## Step 2: Canonicalization

The artifact is transformed into a deterministic byte representation.

Properties:
- Stable ordering
- Explicit byte length
- No hidden metadata
- No environmental influence

If canonicalization changes, signatures break.

This is intentional.

---

## Step 3: Payload Construction

A receipt payload is constructed containing:
- Canonical bytes (or their hash)
- Byte length
- Minimal contextual metadata
- Schema version

The payload is the **only** thing that is signed.

---

## Step 4: Signing

The payload is signed using an SSH-compatible signing key.

Properties:
- Offline-capable
- Human-owned keys
- No central signing authority
- No key discovery

The result is a detached signature file.

---

## Step 5: Storage

The following files now exist:
- Original artifact
- Canonical payload
- Signature file

They may be stored:
- Together
- Separately
- In different systems
- By different parties

HALO-RECEIPTS does not require co-location.

---

## Step 6: Verification (Later)

At any later time, any party may verify:
- The payload matches the artifact
- The signature matches the payload
- The signer key is acceptable

Verification requires:
- The artifact (or its canonical form)
- The payload
- The signature
- An allowed signers list

Nothing else.

---

## Failure Propagation

Any mutation causes failure:
- Artifact changed → payload mismatch
- Payload changed → signature invalid
- Signature missing → verification fails
- Signer unknown → verification fails

There is no partial success.

---

## Temporal Decoupling

Signing and verification are intentionally decoupled.

Properties:
- Different machines
- Different organizations
- Different moments in time
- Different threat models

This is not a weakness.
It is the core design.

---

## What the Flow Does Not Include

Explicitly excluded:
- Identity resolution
- Intent inference
- Authorization decisions
- Trust scoring
- Real-time enforcement

Those occur **outside** the flow, if at all.

---

## Summary

HALO-RECEIPTS flow is linear, minimal, and hostile to ambiguity.

Nothing is implied.
Nothing is inferred.
Nothing is repaired.

Only bytes, signatures, and time remain.
