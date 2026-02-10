# HALO Protocol — Security Addendum v1.0 (Model A)

**Last Updated:** February 10, 2026  
**Applies To:** Services under the MSA where Customer retains private key custody (Customer-Managed Keys).

## 1. Purpose

This Addendum translates HALO’s technical invariants into auditable security commitments. It does not expand scope beyond the MSA Boundary (§2.2).

## 2. System Model

- **Event:** Customer JSON.
- **Canonical Payload:** deterministic bytes derived from Event per Documentation.
- **Envelope:** `.halo.json` wrapper containing integrity metadata + signature metadata.
- **Receipt:** Event + Envelope.
- **Allowed Signers:** Customer-controlled trust store defining which signer identities are authorized.

## 3. Cryptographic Invariants

3.1 **Byte-Exact Integrity Guarantee (Integrity-Protected Fields).** Verification will fail if any single-bit change occurs in integrity-protected fields of the Event or required Envelope fields bound to the Canonical Payload.

3.2 **Extensions Exclusion.** Fields under `extensions` (or other explicitly documented excluded sections) are excluded from integrity protection. Modifying excluded fields MUST NOT cause integrity verification failure.

3.3 **Deterministic Canonicalization.** Canonicalization is deterministic: same input structure + same canonicalization rules => identical Canonical Payload bytes and hash.

3.4 **Hash Algorithm.** Hashing uses the algorithm documented by Vendor (e.g., SHA-256). The algorithm identifier is carried in the Envelope.

3.5 **Signature Verification.** Signatures are verified using documented mechanisms (e.g., OpenSSH signing/verification). Verification failure occurs if signature is invalid for the payload.

3.6 **Signer Authorization.** A receipt signed by a signer not present in Customer’s Allowed Signers MUST fail authorization checks.

## 4. Key Management — Model A

4.1 **No Key Custody by Vendor.** Vendor does not receive, store, escrow, or manage Customer private keys.

4.2 **Customer Responsibilities.** Customer is responsible for generating keys, protecting private keys, controlling access, rotating keys, and incident response related to keys.

4.3 **Recommended Controls (Non-Binding).**
- Use hardware-backed keys where feasible.
- Store private keys in OS keychain/HSM; restrict access via least privilege.
- Rotate keys on personnel changes or suspected compromise.
- Version and sign Allowed Signers where feasible.

## 5. Trust Store Integrity (Allowed Signers)

5.1 **Customer Authority.** Customer maintains ultimate authority over the Allowed Signers list and the authorization policy.

5.2 **Versioning.** Customer SHOULD version Allowed Signers. Verification Output MAY include an `allowed_signers_version` to support audit traceability.

5.3 **Change Impact.** Modifications to Allowed Signers may change authorization outcomes for future verifications. Customer should retain historical versions needed for audit reproduction.

## 6. Deterministic Verification Guarantee

6.1 **Determinism Statement.** Any two installations with identical:
- software version,
- schema definitions,
- canonicalization rules,
- Allowed Signers contents,
MUST produce identical Verification Output for identical inputs.

6.2 **Testability.** Determinism is testable using Vendor’s included verification suite and reference fixtures.

## 7. Threat Model Alignment (High-Level)

Covered threats (intended):
- After-the-fact tampering of integrity-protected fields
- Envelope/signature tampering
- Unauthorized signer attempts
- Schema-invalid Events (if schema validation is enabled)

Not covered (out of scope / Customer-controlled):
- Compromised Customer private keys
- Insider threats within Customer environment
- False/incorrect Event content at time of capture
- Admissibility/jurisdictional legal standards

## 8. Operational Security and Change Management

8.1 **Secure Development (Vendor).** Vendor maintains source control hygiene, code review practices appropriate to project stage, and reproducible dependencies where feasible.

8.2 **Change Control (Vendor).** Vendor will document changes that affect canonicalization, schemas, hashing, verification output formats, or signature verification behavior.

8.3 **Compatibility.** Breaking changes to verification semantics SHOULD be versioned and communicated.

## 9. Incident Response

9.1 **Vendor.** Vendor will make commercially reasonable efforts to remediate security defects in Vendor-controlled code.  
9.2 **Customer.** Customer handles incidents involving Event content, Customer systems, and Customer key custody.

## 10. No Expansion of Scope

Nothing in this Addendum expands Vendor responsibility beyond the MSA Boundary (§2.2).
