# HALO Protocol — Statement of Work (SOW) Template v1.0

**This SOW incorporates the MSA v1.0 and Security Addendum v1.0 (Model A).**

## A. Project Overview

**Customer:** [Customer Legal Name]  
**Vendor:** [Vendor Legal Name]  
**Project Name:** [Name]  
**Effective Date:** [Date]  
**Term:** [Start] – [End] (or “Initial term of 12 months”)

## B. Scope

### B.1 Services
Vendor will provide the following, as applicable:
1) Receipt verification tooling and reference implementation  
2) Integration support for Customer systems (limited to interfaces defined herein)  
3) Schema configuration and validation workflows  
4) Operational runbook guidance for verification pipelines

### B.2 Explicit Non-Scope (Reaffirmation)
Vendor does not interpret content, determine truth, or provide clinical/financial/legal judgments. Vendor does not manage Customer private keys (Model A).

### B.3 Prohibited Data
Customer will not submit Prohibited Data as defined in the MSA. PHI requires a BAA executed prior to submission.

## C. Deliverables

1) Configured verification workflow for Customer-provided schemas  
2) Documentation of canonicalization rules and verification procedure  
3) Verification Output in JSON format per MSA §1.11 (via included tooling)  
4) Acceptance test execution evidence (see Section E)

## D. Customer Dependencies

Customer will provide:
- Schemas and schema versioning policy
- Allowed Signers list (including version identifier if used)
- Non-production test fixtures for acceptance tests
- Access to required environments (if Vendor-assisted deployment is included)

## E. Acceptance Criteria (Objective, Testable)

Acceptance is demonstrated by producing Verification Output JSON matching MSA §1.11 and satisfying the following tests:

### Test 1 — Baseline Verification (PASS)
**Input:** Known-good Event + matching Envelope + Allowed Signers.  
**Pass Condition:** `status="PASS"` AND `checks.schema="PASS"` AND `checks.canonical_hash="PASS"` AND `checks.signature="PASS"` AND `checks.signer_authorized="PASS"`.

### Test 2 — Tamper Detection (FAIL on Integrity)
**Input:** Single-byte modification to an integrity-protected field (schema-valid), using original Envelope.  
**Pass Condition:** `status="FAIL"` AND `checks.canonical_hash="FAIL"` (expected/actual hashes present in `details`).

### Test 3 — Schema Enforcement (FAIL on Schema)
**Input:** Schema-invalid Event.  
**Pass Condition:** `status="FAIL"` AND `checks.schema="FAIL"` AND `details.schema_errors` is non-null.

### Test 4 — Unauthorized Signer (FAIL on Authorization)
**Input:** Receipt signed by a signer not present in Allowed Signers.  
**Pass Condition:** `status="FAIL"` AND `checks.signer_authorized="FAIL"`.

### Test 5 — Extensions Exclusion (PASS)
**Input:** Modify only excluded metadata fields (e.g., `extensions`) while keeping integrity-protected fields unchanged, with matching Envelope.  
**Pass Condition:** Same as Test 1 (PASS). (`checks.canonical_hash="PASS"` confirms exclusions are excluded.)

### Test 6 — Deterministic Verification (PASS/Identical Output)
**Input:** Same Receipt verified in two environments with identical software/schema/trust store.  
**Pass Condition:** Verification Output objects are identical except for `timestamp` (and any explicitly documented non-deterministic fields).

## F. Fees and Payment

**Implementation Fee:** $[amount]  
**Annual License/Support:** $[amount]/year  
**Payment Terms:** Net [15/30] days

## G. Security and Compliance

Security posture is defined in the Security Addendum. Customer maintains key custody (Model A). Vendor may provide best-practice guidance but does not assume custody.

## H. Support

Support hours, response targets, and escalation paths: [define].  
Severity definitions: [define].

## I. Signatures

Customer: ____________________  Date: ________  
Vendor:   ____________________  Date: ________
