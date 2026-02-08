# Runbook: Rotate Keys

## When to rotate
- scheduled rotation (e.g., quarterly)
- suspected compromise
- machine ownership/purpose changes
- decommissioning

## Procedure
1) Generate a new keypair on the machine.
2) Create a rotation receipt linking old signer -> new signer.
3) Add new public key to `keys/allowed_signers/`.
4) Verify new key can sign and verify.
5) Revoke old key (move to `keys/revoked_signers/`) after overlap window.
6) Document the rotation decision in `governance/decisions/`.

## Emergency rotation (suspected compromise)
- Skip overlap window.
- Immediately remove old signer from allowlist.
- Add to revoked with reason + timestamp.
- Treat all receipts after compromise time as invalid by policy.

