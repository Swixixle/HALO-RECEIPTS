# Non-Goals Lens

This lens defines what HALO-RECEIPTS explicitly does not attempt to do.

HALO-RECEIPTS is intentionally minimal. Any capability not listed as a core guarantee
is considered out of scope by design.

---

## Explicit Non-Goals

HALO-RECEIPTS does not:

- Assert that content is true, accurate, or factual
- Assert that content is safe, benign, or non-malicious
- Assert intent, meaning, or context behind the bytes
- Assert authorship, ownership, or originality
- Assert identity beyond cryptographic key possession
- Assert that a signer was acting legitimately or ethically
- Assert that a signer key was uncompromised
- Assert that content should be trusted, executed, or believed
- Perform content validation, moderation, or classification
- Enforce policy, governance, or compliance rules
- Provide time-based guarantees beyond signature verification
- Prevent misuse, misinterpretation, or downstream abuse

---

## Design Rationale

HALO-RECEIPTS separates existence from interpretation.

By refusing to embed meaning, intent, or trust judgments into the receipt itself,
HALO-RECEIPTS avoids false authority, policy coupling, and semantic drift.

All interpretation is intentionally deferred to downstream systems, reviewers,
or governance frameworks.

---

## Implications

- A valid receipt does not imply approval
- A verified signature does not imply endorsement
- An unchanged payload does not imply legitimacy
- A trusted key does not imply a trusted actor

HALO-RECEIPTS proves only one thing:

That specific bytes existed and were signed by a specific key.

Everything else is external.
