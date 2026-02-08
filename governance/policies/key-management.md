# Key Management Policy

## Purpose
This document defines how signing keys are created, stored, used, rotated, and revoked.

The system is only as trustworthy as its private key hygiene.

## Key Types
- **Signer keypair**: used to sign receipts
- **Trust root (optional)**: a higher-trust signer used to enroll or bless other signers

## Generation
- Keys MUST be generated locally on the machine that will use them.
- Private keys MUST NOT be copied to other machines.
- Private keys MUST NOT be committed to git, ever.

## Storage
- Private keys must be stored locally with restricted permissions.
- Public keys are stored in-repo:
  - `keys/allowed_signers/` for active signers
  - `keys/revoked_signers/` for revoked signers (with metadata)

## Use
- Signing operations must reference a local private key.
- Verification must reference only repo-tracked allowlists/trust roots.

## Rotation
Rotation is REQUIRED:
- on a fixed schedule (e.g., quarterly), OR
- immediately upon suspected compromise, OR
- when a machine changes ownership/purpose.

Rotation steps (high-level):
1) generate new keypair
2) produce a rotation receipt (old signer -> new signer)
3) add new public key to allowlist
4) revoke old key after a defined overlap window

## Revocation
Revocation is REQUIRED:
- upon compromise
- upon loss/theft of machine
- upon policy violation
- upon decommission

Revocation steps:
1) remove from `keys/allowed_signers/`
2) add to `keys/revoked_signers/` with reason + date
3) receipts signed after revocation timestamp are invalid by policy

## Non-negotiables
- No shared private keys
- No emailing private keys
- No private keys in logs, screenshots, or tickets
- Allowlist is the sole trust gate for verification

