# Security Lens

This document describes what HALO-RECEIPTS **does and does not secure**, and the threat assumptions under which it is designed to operate.

HALO-RECEIPTS is a *cryptographic attestation primitive*, not a security platform.

---

## What HALO-RECEIPTS Secures

HALO-RECEIPTS provides strong guarantees for the following properties:

### 1. Payload Integrity
Any modification to a signed receipt’s canonical payload will cause signature verification to fail.

- Byte-exact canonicalization
- Deterministic payload derivation
- Cryptographic binding between payload and signature

If verification succeeds, the verifier can assert that **the signed bytes are identical to the bytes originally signed**.

---

### 2. Signer Authenticity (Key-Bound)
Verification confirms that the payload was signed by a private key corresponding to a public key listed in the verifier’s `allowed_signers` file.

- Uses OpenSSH `ssh-keygen -Y`
- Leverages existing SSH trust and key management practices
- No custom crypto primitives

HALO-RECEIPTS does not invent identity — it relies on **explicit key trust configured by the verifier**.

---

### 3. Offline & Deterministic Verification
Verification can be performed:

- Offline
- Without network access
- Without contacting the signer
- Without mutable external services

This prevents retroactive alteration, revocation-by-service, or trust drift through centralized dependencies.

---

## Threats Explicitly Addressed

HALO-RECEIPTS is designed to resist:

- **Post-hoc modification** of receipts or payload fields
- **Silent alteration** of audit artifacts
- **Replay of altered evidence**
- **Ambiguity about what bytes were actually signed**
- **Toolchain drift** causing non-deterministic verification

---

## Threats Explicitly Out of Scope

HALO-RECEIPTS does **not** attempt to mitigate:

- Compromise of the signer’s private key
- Malicious or coerced signers
- False, misleading, or fraudulent data being signed
- Time accuracy beyond what is encoded in the receipt
- Identity spoofing beyond SSH key trust
- Key revocation, rotation, or lifecycle management
- Secure storage or transmission of receipts

These are *upstream or downstream concerns* by design.

---

## Security Model Summary

HALO-RECEIPTS assumes:

- The verifier controls the trusted public keys
- The signer is accountable for what they sign
- Verification logic is deterministic and inspectable
- Trust boundaries are explicit and local

HALO-RECEIPTS **does not outsource trust to policy, intent, or interpretation**.

It only answers one security question:

> *Do these exact bytes match what a trusted key signed?*

Nothing more. Nothing less.

---

## Design Philosophy

Security failures often arise from systems that claim more than they can prove.

HALO-RECEIPTS is intentionally narrow:
- Fewer claims
- Fewer assumptions
- Fewer attack surfaces

Its strength comes from **refusal**, not coverage.
