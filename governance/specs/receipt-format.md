# Receipt Format Specification

## Purpose
A receipt is a cryptographically verifiable record of an event, decision, or action.

Receipts must be:
- deterministic
- human-readable
- machine-verifiable
- tamper-evident

## Required Fields
Every receipt MUST contain:

- `receipt_id` — unique identifier
- `type` — category of receipt (e.g., decision, enrollment, action)
- `issued_at` — ISO-8601 timestamp
- `issuer` — signer identity
- `subject` — what the receipt concerns
- `payload` — structured, deterministic data
- `hash` — hash of canonical receipt contents
- `signature` — cryptographic signature of the hash

## Canonicalization Rules
- Field order is fixed and deterministic
- No optional fields may affect the hash
- Whitespace and formatting must not affect hash output

## Trust Rule
A receipt is valid if and only if:
1) its hash verifies,
2) its signature verifies,
3) the signer is present in the allowlist at verification time.

## Invalidity
A receipt is invalid if:
- any required field is missing,
- the hash does not match contents,
- the signature fails verification,
- the signer has been revoked.

## Versioning
Receipt format changes require:
- explicit version bump,
- backward compatibility note,
- governance decision record.

