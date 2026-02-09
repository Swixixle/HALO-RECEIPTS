# Operations Lens

This lens describes how HALO-RECEIPTS is used, handled, and maintained in real operational environments.

It is intentionally boring.

HALO-RECEIPTS is not a platform, service, or runtime dependency. It is an artifact-level primitive designed to survive organizational churn, tooling changes, and personnel turnover.

---

## Operational Posture

HALO-RECEIPTS operates as a **detached attestation step**, not a live system.

Typical properties:
- No daemon
- No long-running service
- No required network access
- No centralized authority
- No availability guarantees

If HALO-RECEIPTS is “down,” nothing is down. Signing simply does not occur.

---

## Lifecycle Placement

HALO-RECEIPTS appears at **boundaries**, not in workflows.

Common placements:
- Pre-deployment artifact sealing
- Post-incident snapshotting
- Evidence capture prior to handoff
- Audit or compliance freeze points
- Model / prompt / policy version sealing

It is not used continuously. It is used **deliberately**.

---

## Key Management

Operational responsibility for keys is external to HALO-RECEIPTS.

Typical models:
- Individual operator SSH keys
- Team-scoped signing keys
- Hardware-backed keys where available

HALO-RECEIPTS does not:
- Rotate keys
- Revoke keys
- Distribute keys
- Enforce key policy

Operational key policy is documented elsewhere and enforced socially or procedurally.

---

## Failure Modes

Expected and acceptable failures:
- Signature verification failure
- Missing payload or signature file
- Unknown or unauthorized signer
- Schema validation failure

All failures are **loud** and **terminal**.

There is no retry logic, fallback mode, or silent degradation.

---

## Incident Use

HALO-RECEIPTS is explicitly designed for adversarial or post-incident environments.

Assumptions:
- The system may already be compromised
- Logs may be incomplete or manipulated
- Trust in operators may be limited
- Intent may be disputed

HALO-RECEIPTS only preserves one fact:
> These exact bytes existed and were signed by this key at that moment.

---

## Organizational Fit

HALO-RECEIPTS fits best in environments that value:
- Separation of concerns
- Minimal trust surfaces
- Artifact-level accountability
- Post-hoc verification over real-time enforcement

It is poorly suited to:
- High-availability systems
- Real-time policy enforcement
- User-facing applications
- Centralized governance platforms

---

## Operational Discipline

HALO-RECEIPTS rewards restraint.

Operational anti-patterns:
- Auto-signing everything
- Signing mutable artifacts
- Embedding business logic in receipts
- Treating receipts as proof of correctness

Correct usage is sparse, intentional, and boring.

That is the point.
