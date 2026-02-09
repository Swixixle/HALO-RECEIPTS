# Threat Model — HALO-RECEIPTS (v0.1)

This document defines the security boundaries, assumptions, threats, and non-claims of HALO-RECEIPTS.

HALO-RECEIPTS is intentionally narrow. It does not attempt to solve trust, truth, or intent.  
It exists to make tampering visible.

---

## 1. System Boundary

### In Scope
- Canonicalization of receipt input into deterministic payload bytes
- Cryptographic signing of derived payloads
- Verification of signatures using OpenSSH `ssh-keygen -Y`
- Enforcement of allowed signers
- Schema validation as a structural gate (not a semantic guarantee)
- Exit codes suitable for automation and policy enforcement

### Explicitly Out of Scope (Non-Claims)
- Truth or accuracy of content
- Intent, meaning, or authorship beyond key possession
- Identity verification beyond cryptographic key control
- Endpoint security of signer or verifier machines
- Protection against private key compromise
- Trusted timestamps or time authority
- Content moderation, safety, or correctness

HALO-RECEIPTS does **not** prevent lies.  
It prevents silent modification.

---

## 2. Security Goals

HALO-RECEIPTS is considered “secure” if and only if the following hold:

**G1 — Tamper Evidence**  
Any modification to signed bytes results in signature verification failure.

**G2 — Deterministic Derivation**  
Identical receipt inputs produce identical payload bytes under a given canonicalization version.

**G3 — Authorized Verification**  
Only signatures produced by keys listed in the configured `allowed_signers` file are accepted.

**G4 — Automatable Verification**  
Verification produces unambiguous success/failure signals suitable for CI, policy engines, and audits.

---

## 3. Trust Assumptions

The verifier implicitly trusts:

- The correctness of OpenSSH’s `ssh-keygen -Y` implementation
- The integrity and authenticity of the `allowed_signers` file
- That private signing keys are controlled by their owners
- That canonicalization rules are unambiguous and versioned
- That verification is performed on the intended files

If these assumptions do not hold, HALO-RECEIPTS makes no safety guarantees.

---

## 4. Assets

The primary assets protected by HALO-RECEIPTS are:

- Private signing keys (highest value)
- `allowed_signers` policy file
- Canonicalization specification and implementation
- Receipt JSON files
- Derived payload bytes
- Signature artifacts
- Audit trails relying on verification results

---

## 5. Threat Analysis (STRIDE)

### S — Spoofing (Impersonation)

**Threats**
- Attacker adds their public key to `allowed_signers`
- Verifier is tricked into using an attacker-controlled `allowed_signers` file

**Mitigations**
- Treat `allowed_signers` as a governance artifact, not a convenience file
- Restrict write access via filesystem permissions and code review
- Reference `allowed_signers` explicitly (path or pinned artifact) in automation
- Future: sign or attest to `allowed_signers` itself as a policy artifact

---

### T — Tampering

**Threats**
- Receipt JSON modified after signing
- Canonicalization ambiguities exploited across platforms
- Payload regenerated using different rules than intended

**Mitigations**
- Deterministic, documented canonicalization rules
- Explicit canonicalization version identifiers
- Verification over derived payload bytes, not raw JSON
- Test vectors to lock canonicalization behavior

---

### R — Repudiation

**Threats**
- Signer claims they did not authorize the signed content
- Signer claims key compromise after the fact

**Mitigations**
- HALO-RECEIPTS does not attempt to resolve intent disputes
- Audit artifacts include key identifiers and signing context
- Key rotation and revocation are governance responsibilities
- Repudiation is handled procedurally, not cryptographically

---

### I — Information Disclosure

**Threats**
- Sensitive data embedded directly in receipt JSON
- Payloads or signatures leaked via logs, CI artifacts, or commits

**Mitigations**
- Do not include PHI, PII, or secrets in receipts
- Prefer signing hashes or references for sensitive content
- Exclude generated payloads and signatures via `.gitignore`
- Keep verification non-networked by default

---

### D — Denial of Service

**Threats**
- Extremely large or malformed inputs cause slow parsing or crashes
- Verification scripts blocked or misused in automation

**Mitigations**
- Enforce reasonable size limits on receipts
- Fail fast with explicit error messages and exit codes
- Avoid network calls during verification
- Keep verifier scripts minimal and dependency-light

---

### E — Elevation of Privilege

**Threats**
- Private signing key stolen from developer or CI environment
- Compromised CI signs malicious artifacts

**Mitigations**
- Recommend hardware-backed keys for production use
- Separate signing environments from general development
- Require review for changes to `allowed_signers`
- Treat signing capability as privileged infrastructure access

---

## 6. Known Limitations

- `created_at` fields are informational only and not trusted timestamps
- `allowed_signers` integrity is a single point of failure unless separately protected
- Key compromise invalidates trust until keys are rotated or revoked
- Schema validation enforces structure, not meaning

These limitations are deliberate and documented.

---

## 7. Security Roadmap (Non-Binding)

Potential future enhancements include:

- Signed or attested `allowed_signers` policy artifacts
- Canonicalization regression test corpus
- Optional integration with trusted timestamp authorities
- Transparency logs for receipt publication
- Formal verifier bindings in additional languages

None of these are required for the core security guarantees.

---

## 8. Summary

HALO-RECEIPTS provides **tamper-evident proof of byte existence and signature**.

It does not claim truth.  
It does not claim intent.  
It does not claim authorship.

It draws a hard boundary — and enforces it cryptographically.
