# Governance

This folder is the canonical source of truth for HALO-RECEIPTS rules.

## What must be true for trust
A receipt is trusted only if:
1) it conforms to the canonical receipt format/spec, and
2) it verifies against the current allowlist of signers, and
3) the signer is an enrolled machine identity governed by these policies.

## Canonical artifacts
- Receipt format spec: governance/specs/receipt-format.md
- Key management policy: governance/policies/key-management.md
- Machine enrollment policy: governance/policies/machine-enrollment.md
- Threat model: governance/threat-models/threat-model.md
- Runbooks: governance/runbooks/
- Decisions (ADRs): governance/decisions/

