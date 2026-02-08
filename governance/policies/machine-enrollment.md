# Machine Enrollment Policy

## Goal
A machine may sign receipts only after it is enrolled and its public key is added to the allowlist.

## Definitions
- **Signer**: a named identity with a public key (e.g., `halo-signer`)
- **Allowlist**: `keys/allowed_signers/` containing approved signer public keys
- **Enrollment receipt**: a signed statement binding a machine profile to a signer key

## Enrollment protocol (MUST)
1) **Generate keypair on the new machine**
   - Private key stays on that machine only.
2) **Create a machine profile**
   - Machine name, owner, purpose, created date.
3) **Create an enrollment receipt**
   - Includes: signer name, machine profile hash, public key, timestamp.
4) **Have an already-trusted signer sign the enrollment receipt**
   - This establishes a chain from an existing trust root.
5) **Add the new signer public key to the allowlist**
   - Place the public key in `keys/allowed_signers/<signer>.pub`
6) **Verification requirement**
   - A machine is trusted only if:
     - enrollment receipt signature verifies, AND
     - the signer public key is present in allowlist, AND
     - the enrollment receipt binds the machine profile to that signer.

## Revocation
- If a machine is compromised:
  1) remove its public key from allowlist
  2) add it to `keys/revoked_signers/` with a reason + date
  3) receipts signed after revocation date are invalid by policy

## Non-negotiables
- No shared private keys.
- No “temporary” bypass.
- Allowlist is the canonical trust gate.

