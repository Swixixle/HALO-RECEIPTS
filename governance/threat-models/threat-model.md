# Threat Model

## Scope
HALO-RECEIPTS protects the integrity of signed receipts and the trust boundary around signers.

## Assets
- Private signing keys
- Allowlist of trusted signers
- Receipt canonicalization + hashing rules
- Verification scripts and their assumptions

## Adversaries
- External attacker with repo read access
- Attacker with local machine access (stolen laptop, malware)
- Insider with push access attempting to bless a malicious signer
- “Environment attacker” (compromised runtime, tampered scripts)

## Primary Threats
1) **Key exfiltration**
   - Private key copied, stolen, or logged.
2) **Allowlist tampering**
   - Malicious key added to `keys/allowed_signers/`.
3) **Receipt tampering**
   - Payload modified after signing.
4) **Canonicalization mismatch**
   - Different machines hash “the same” receipt differently.
5) **Replay / substitution**
   - Old valid receipt reused to assert a new event.
6) **Script supply-chain**
   - Verification/signing scripts altered or replaced.

## Mitigations (repo-level)
- Governance requires explicit allowlist + revocation process.
- No private keys in repo, ever.
- Deterministic receipt format spec.
- Enrollment receipts require an already-trusted signer.
- Rotate keys on schedule or compromise.
- Review/approval discipline for changes to `keys/allowed_signers/` and scripts.

## Residual Risk
- If a trusted private key is compromised, attacker can sign valid receipts until revoked.
- If repo push access is compromised, allowlist integrity is at risk.

## Operational Recommendations
- Require PR review for changes to:
  - `keys/allowed_signers/`
  - `keys/revoked_signers/`
  - `scripts/`
  - governance policies/specs
- Keep a minimal trusted set of signers.

