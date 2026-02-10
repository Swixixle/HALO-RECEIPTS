# HALO Protocol — Master Services Agreement (MSA) v1.0

**Last Updated:** February 10, 2026  
**Operating Model:** Customer-Managed Keys (Model A)

> This is a contract template intended to be reviewed with qualified counsel before production use in regulated environments.

## 1. Definitions

1.1 **“Affiliate”** means an entity that controls, is controlled by, or is under common control with a party.  
1.2 **“Allowed Signers”** means the Customer-controlled allowlist of signer identities and associated public keys used to determine signer authorization for Receipts.  
1.3 **“Canonical Payload”** means the deterministic bytes derived from an Event per the Documentation that are hashed for integrity verification.  
1.4 **“Documentation”** means the technical documentation published by Vendor for the Services, including repository docs and specifications.  
1.5 **“Event”** means Customer’s domain JSON input submitted for notarization/verification.  
1.6 **“Envelope”** means the cryptographic wrapper (e.g., `.halo.json`) containing integrity and signature metadata bound to the Canonical Payload.  
1.7 **“Receipt”** means the conceptual unit formed by Event + Envelope.  
1.8 **“Services”** means Vendor’s software, scripts, tooling, and optional support services that perform Receipt generation and/or verification as described in the SOW.  
1.9 **“Prohibited Data”** means: (a) Protected Health Information (“PHI”) absent a fully executed Business Associate Agreement (“BAA”); (b) payment card data subject to PCI-DSS; (c) government identifiers (e.g., SSN, passport numbers); (d) authentication secrets (passwords, API keys, private keys); (e) any data Customer is not authorized to submit.  
1.10 **“SOW”** means a Statement of Work signed by both parties that references this MSA and defines scope, deliverables, fees, and acceptance criteria.  
1.11 **“Verification Output”** means a machine-readable JSON object containing:
- `status`: `"PASS"` or `"FAIL"`
- `timestamp`: ISO 8601 verification time
- `receipt_id`: a traceable hash identifier for the Receipt or Event
- `checks`: `{ schema, canonical_hash, signature, signer_authorized }` each `"PASS"` or `"FAIL"`
- `details`: `{ failure_reason, schema_errors, expected_hash, actual_hash, signer_identity, allowed_signers_version }` with values or `null`

## 2. Scope and Boundary

2.1 **Scope.** Services provide cryptographic notarization and verification of Receipts, including: schema validation, canonicalization, hashing, signature verification, and signer authorization checks against Allowed Signers.

2.2 **Non-Scope / Boundary (Critical).** Services do **not** determine, evaluate, interpret, or warrant the truth, correctness, clinical validity, financial validity, legality, intent, meaning, provenance, or appropriateness of any Event content. Services do **not** provide clinical, financial, legal, or compliance advice. Services do **not** manage Customer’s private signing keys under Model A.

2.3 **No Admissibility Guarantee.** Vendor does not guarantee Receipts will be accepted by any court, regulator, insurer, or third party. Legal admissibility depends on jurisdiction and Customer’s broader recordkeeping and controls.

## 3. Customer Responsibilities

3.1 **Accuracy & Authorization.** Customer is solely responsible for the accuracy, completeness, and authorization of all submitted Events and any downstream use.

3.2 **No Prohibited Data.** Customer will not submit Prohibited Data. If Customer requires PHI processing, a BAA must be executed prior to submission.

3.3 **Compliance.** Customer is responsible for compliance with applicable laws and regulations governing Customer’s data and use-cases.

3.4 **Operational Controls.** Customer will maintain appropriate access controls, audit trails, backups, change control, and incident response processes for systems in Customer’s control.

## 4. Key Management — Model A (Customer-Managed Keys)

4.1 **Customer Custody.** Customer retains custody and control of all private keys. Vendor does not receive, store, escrow, or manage Customer private keys.

4.2 **Key Compromise.** Customer is responsible for key compromise, misuse, loss, or rotation of Customer private keys. Verification outcomes depend on the integrity of Customer’s key custody.

4.3 **Allowed Signers Authority.** Customer maintains ultimate authority over the Allowed Signers list. Customer is responsible for its correctness, versioning, and distribution within Customer environments.

## 5. Fees and Payment

5.1 Fees and payment terms are set forth in the applicable SOW.  
5.2 Late payments may accrue interest at the lesser of 1.5% per month or the maximum permitted by law.

## 6. Confidentiality

6.1 Each party may receive confidential information (“Confidential Information”). The receiving party will protect Confidential Information using reasonable measures and will not disclose it except to employees/contractors with a need to know who are bound by confidentiality obligations.

6.2 Confidential Information excludes information that is publicly available, independently developed, or lawfully received without restriction.

## 7. Warranty and Disclaimers

7.1 **Limited Technical Warranty.** Vendor warrants that Services will perform materially in accordance with Documentation with respect to:
- canonicalization and hash computation for integrity-protected fields,
- signature verification logic,
- signer authorization checks against Allowed Signers (as provided by Customer),
- generation of Verification Output per §1.11 (if included in SOW).

7.2 **Remedy.** Customer’s exclusive remedy for breach of §7.1 is re-performance or, if Vendor cannot re-perform, refund of fees paid for the affected Services during the prior 30 days.

7.3 **No Truth Warranty.** Vendor does not warrant the truth, correctness, provenance, or validity of any Event content.

7.4 **Disclaimer.** EXCEPT AS EXPRESSLY PROVIDED, SERVICES ARE PROVIDED “AS IS” AND VENDOR DISCLAIMS ALL IMPLIED WARRANTIES, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

## 8. Limitation of Liability

8.1 **No Indirect Damages.** NEITHER PARTY WILL BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR LOST PROFITS, REVENUE, OR BUSINESS INTERRUPTION.

8.2 **Liability Cap.** VENDOR’S TOTAL LIABILITY ARISING OUT OF OR RELATED TO THIS MSA WILL NOT EXCEED THE FEES PAID BY CUSTOMER UNDER THE APPLICABLE SOW IN THE TWELVE (12) MONTHS PRECEDING THE EVENT GIVING RISE TO LIABILITY.

8.3 **Allocation of Risk.** The parties agree the limitations reflect allocation of risk and are essential to the bargain.

## 9. Indemnification

9.1 **Customer Indemnity.** Customer will defend and indemnify Vendor from third-party claims arising from: (a) Event content; (b) submission of Prohibited Data; (c) Customer’s violation of law; (d) misuse of Services; (e) claims that Services determined or warranted truth/meaning contrary to §2.2.

9.2 **Vendor IP Indemnity (Optional).** If included in a SOW, Vendor will indemnify Customer against third-party claims alleging Services infringe IP rights, excluding claims arising from Customer materials, modifications, or combination with non-Vendor systems.

## 10. Term and Termination

10.1 **Term.** This MSA begins on the effective date of the first SOW and continues until terminated.

10.2 **Termination for Cause.** Either party may terminate for material breach not cured within 30 days after notice.

10.3 **Effect.** Upon termination, Customer will pay fees accrued. Sections intended to survive do survive.

## 11. Acceptance Criteria (SOW-Controlled)

11.1 Deliverables and acceptance criteria are defined in the SOW and may reference automated test suites (e.g., e2e verification scripts) as objective acceptance.

## 12. Miscellaneous

12.1 **Independent Contractors.** The parties are independent contractors.  
12.2 **Governing Law.** As specified in the SOW; absent SOW, Vendor’s home jurisdiction.  
12.3 **Entire Agreement.** This MSA + SOW(s) + addenda are the entire agreement.  
12.4 **Order of Precedence.** SOW overrides MSA for scope/fees; Security Addendum overrides for security terms.  
