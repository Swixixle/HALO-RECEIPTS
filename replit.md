# AI Receipts - Forensic Verification System

## Overview
AI Receipts is a forensic verification system for AI conversation transcripts. It provides cryptographic verification of receipt capsules, immutable storage, and forensic analysis capabilities.

## Core Features
- **Receipt Verification**: Validates AI conversation receipts using SHA-256 hash verification
- **Canonicalization (c14n-v1)**: Deterministic JSON canonicalization for consistent hashing
- **Immutable Storage**: Verified receipts are locked and cannot be modified
- **Kill Switch**: Irreversible control to permanently disable interpretation for a receipt
- **Interpretation System**: Categorized as FACT, INTERPRETATION, or UNCERTAINTY (append-only)
- **Tri-Sensor Analysis**: Parallel analysis with interpreter, summarizer, and claim extractor

## API Endpoints

### Verification
- `POST /api/verify` - Verify and store a receipt capsule
- `GET /health` - Health check

### Receipt Management
- `GET /api/receipts` - List all receipts
- `GET /api/receipts/:receiptId` - Get receipt detail with interpretations
- `POST /api/receipts/:receiptId/kill` - Engage kill switch (irreversible)

### Interpretation
- `POST /api/receipts/:receiptId/interpret` - Add interpretation (guarded)
- `POST /api/receipts/:receiptId/tri-sensor` - Run tri-sensor analysis

### Export & Configuration (P1)
- `GET /api/receipts/:receiptId/export` - Export complete forensic report (JSON)
- `GET /api/config/transcript-mode` - Get current transcript display mode

## Data Schemas

### Receipt Capsule (Input)
```json
{
  "schema": "ai-receipt/1.0",
  "receipt_id": "string",
  "platform": "string",
  "captured_at": "ISO-8601",
  "capture_agent": "string",
  "transcript": {
    "embedded": true,
    "canonicalization": "c14n-v1",
    "messages": [{"role": "user|assistant|system|tool", "content": "string"}]
  },
  "transcript_hash_sha256": "hex-string",
  "signature": {"alg": "Ed25519", "public_key_id": "string", "value": "string"}
}
```

### Verification Status
- **VERIFIED**: Hash match + VALID signature + (LINKED|GENESIS chain)
- **PARTIALLY_VERIFIED**: Hash match + (UNTRUSTED_ISSUER|NO_SIGNATURE signature)
- **UNVERIFIED**: Hash mismatch OR INVALID signature OR BROKEN chain

## Ed25519 Signature Verification (P2/P3 Completed)
- **Key Registry**: `server/key-registry.ts` - maps public_key_id to Ed25519 public keys
- **Signature Statuses**: VALID, INVALID, UNTRUSTED_ISSUER, NO_SIGNATURE
- **P3 Key Governance**: ACTIVE/REVOKED/EXPIRED status, valid_from, valid_to, issuer_label, revoked_reason
- **Key Rotation**: Multiple keys per issuer supported
- **Test Keys**: test-key-001, test-key-002-rotated (trusted), revoked-key-001, expired-key-001, untrusted-key-001

## Receipt Chain Verification (P2 Completed)
- **Chain Module**: `server/chain-verification.ts` - verifies chain links
- **Chain Statuses**: GENESIS, LINKED, BROKEN, NOT_CHECKED
- **Chain Hash Formula**: SHA256(c14n(capsule_core)) - deterministic canonicalization of signed core fields
- **Chain Field Naming**:
  - `expected_previous_hash`: Value in submitted receipt's previous_receipt_hash_sha256 (submitter's claim)
  - `observed_previous_hash`: Computed receipt_hash_sha256 from stored prior receipt (verifier's computation)
  - `link_match`: true if expected === observed

## Public Verification Endpoint (P3)
- `GET /api/public/receipts/:receiptId/verify` - Shareable verification result
- Respects TRANSCRIPT_MODE (full/redacted/hidden)
- Returns: schema, verification_status, signature summary, chain summary, integrity, forensics
- Never leaks raw transcript in hidden mode

## Forensic Detectors (P0 Completed)
The forensics engine (`detectors/0.1.0`) runs independently of verification status:
- **based_on**: `"verified_transcript"` for VERIFIED/PARTIALLY_VERIFIED, `"submitted_payload"` for UNVERIFIED
- **integrity_context**: Records verification status at time of analysis
- **Risk Keywords (Heuristic)**: Pattern matching only (instructional, medical, legal, financial, self_harm)
- **High-Entropy Detection**: Pattern-based `[A-Za-z0-9+/]{80,}={0,2}` (NOT Shannon entropy)
- **PII Heuristics**: Returns counts only, never raw values

## Rate Limiting & Authentication (P4 Completed)
- **Rate Limiter Module**: `server/rate-limiter.ts` - Per-IP burst + sustained limits
- **Auth Module**: `server/auth.ts` - API key authentication
- **Production Policy**: Public verify-by-id only (Option 1)
  - Public: `GET /api/public/receipts/:id/verify` (rate limited, no auth)
  - Private: `POST /api/verify` (auth required - prevents storage spam)
- **Rate limits**:
  - Public verify: 100/min sustained, 10/sec burst
  - Private verify: 50/min sustained, 5/sec burst
- **Private endpoints**: All /api/* require x-api-key header
- **Request size cap**: 100KB default (Express body-parser), middleware rejects >1MB
- **Dev test key**: "dev-test-key-12345" (only when NODE_ENV !== "production")
- **Error responses**: 
  - 401 Unauthorized - Missing API key (non-revealing message)
  - 403 Forbidden - Invalid API key (non-revealing message)
  - 429 Too Many Requests - Rate limit exceeded (includes Retry-After header)
  - 413 Payload Too Large - Request body exceeds size limit

## Guards & Constraints
1. Unverified receipts cannot be interpreted
2. Kill switch is irreversible and blocks all interpretation
3. Interpretations are append-only (no UPDATE/DELETE)
4. Immutable lock prevents raw JSON modification
5. Private endpoints require valid API key (P4)

## Technology Stack
- Frontend: React + TypeScript + Tailwind CSS + shadcn/ui
- Backend: Express.js + Node.js 20
- Database: PostgreSQL with Drizzle ORM
- Validation: Zod schemas
- Cryptography: Node.js crypto (SHA-256)

## Sample Test Files
- `samples/valid_capsule.json` - Valid receipt with matching hash
- `samples/tampered_capsule.json` - Tampered receipt with hash mismatch

## LLM Integration - Sensor Mode Only (P6 Completed)
- **Schema Module**: `shared/llm-observation-schema.ts`
- **Service Module**: `server/llm-sensor.ts`
- **Schema Version**: llm-observation/1.0
- **Purpose**: LLMs observe and describe transcripts but NEVER judge truth/validity

### Core Principle: LLMs as Sensors, Not Arbiters
- LLMs see ONLY transcript content (DATA ISOLATION)
- LLM observations do NOT affect verification_status, signature_status, or chain_status
- LLM observations are stored separately from interpretations and research data
- Multi-model disagreement is displayed WITHOUT reconciliation (no "correct" answer)

### Observation Endpoints
- `POST /api/receipts/:id/observe` - Generate single-model observation
- `GET /api/receipts/:id/observations` - List observations for receipt
- `POST /api/receipts/:id/observe/multi` - Multi-model disagreement detection

### Observation Types
- `paraphrase`, `ambiguity`, `disagreement`, `tone`, `structure`, `hedging`, `refusal_pattern`

### Language Hygiene (Strictly Enforced)
Forbidden words (rejected with error):
- `correct`, `incorrect`, `true`, `false`, `hallucination`, `accurate`, `wrong`, `right`
- `proves`, `verified`, `invalid`, `therefore`, `misleading`, `deceptive`, `lying`

Required hedging (auto-prefixed if missing):
- `may`, `might`, `appears`, `could`, `seems`, `possibly`, `potentially`, `suggests`, `indicates`

### Mandatory Fields (Always Present)
- `confidence_statement`: "This is a model-generated observation, not a factual determination."
- `limitations`: Array of at least 2 limitation statements

### Data Isolation
- LLM sensor receives ONLY: transcript messages, observation_type, model_id
- LLM sensor NEVER receives: verification_status, signature_status, chain_status, forensics
- LLM observations table is separate from interpretations and research records

### Kill Switch Interaction
- Kill switch hides all existing observations
- Kill switch blocks creation of new observations
- Response includes `kill_switch_engaged: true`

### Mock Sensor Model
- `mock-sensor` model available for testing without API keys
- Returns deterministic observations based on observation_type

## Research Dataset Schema (P5 - Completed)
- **Schema Module**: `shared/research-schema.ts`
- **Schema Version**: research-record/1.0, research-dataset/1.0, research-consent/1.0
- **Purpose**: Anonymized, aggregatable research data for model behavior analysis

### What IS Included (safe to export)
- Verification/signature/chain outcomes (categorical)
- Platform category (normalized: openai, anthropic, google, meta, mistral, cohere, other, unknown)
- Structural statistics (message counts, bucketed char counts)
- Anomaly indicators (boolean flags only)
- Risk category presence (boolean per category, no counts)
- PII presence indicators (detected yes/no, never values)
- Time buckets (day-level only, no exact timestamps)
- Kill switch status, interpretation counts

### What is NEVER Included (explicit exclusions)
- Raw transcripts or message content
- Receipt IDs or correlation identifiers
- IP addresses or user identifiers
- Exact timestamps (only day buckets)
- Raw signatures or public key values
- Actual PII values (only detection flags)
- Keyword instances (only category presence)

### Consent Model
- Opt-in required before research data creation
- Consent scope: anonymized_statistics, model_behavior_research, academic_publication, commercial_datasets
- Revocation support with timestamp tracking

## Tamper-Evident Share Pack System (P6 Hardened)
- **EVENT_LOG.jsonl**: Hash-chained forensic log with SHA256-based chain integrity
- **Verification Scripts**: verify_forensic_state.ts, snapshot_state.ts, build_share_pack.ts
- **Proof Update Pipeline**: script/proof_update.ts runs verify, snapshot, build, and logs PROOF_PACK_UPDATED
- **Independent Verification**: Third parties can verify chain integrity using Python/Node scripts (see INDEPENDENT_VERIFY.md)

### Share Pack Redaction Policy
- URLs, IPs, API keys, non-synthetic receipt IDs all redacted
- Synthetic ID patterns allowed: `^(p[0-9]+-|test-|sample-|mock-|synthetic-)`
- UUID-format strings without synthetic prefix redacted to [UUID_REDACTED]
- Case-insensitive forbidden word detection for platform-specific terms

### Milestone Events Logged
- VERIFY_STORED: Receipt verified and stored
- KILL_SWITCH_ENGAGED: Kill switch activated
- OBSERVE_CREATED: Single LLM observation created
- OBSERVE_MULTI_CREATED: Multi-model observation created
- RESEARCH_RECORD_WRITTEN: Research record created
- RESEARCH_EXPORT_GENERATED: Research dataset exported
- PROOF_PACK_UPDATED: Proof pack fully updated

## Future: Receipt Capsule v2 (Proposed)
See `docs/RECEIPT_CAPSULE_V2.md` for a proposed schema evolution featuring:
- Per-line commitment chains (LINE_CHAIN_V1) instead of embedded transcripts
- Cryptographic redaction commitments
- Policy constraints signed into payload
- Event log commitments

This is documented for future consideration but not yet implemented.

## Bulk Export v1 (Completed)
- **Schema**: `export_jobs` table with exportId, status, scope, filtersJson, total, completed, filePath, errorMessage, createdAt, expiresAt
- **Backend Routes**:
  - `POST /api/receipts/bulk-export` - Create export job (auth required)
  - `GET /api/exports/:exportId` - Get job status
  - `GET /api/exports/:exportId/download` - Download ZIP when READY
- **ZIP Contents**: receipts.jsonl, receipts.csv, proof_urls.csv, manifest.json, README.txt
- **Generator**: `server/bulk-export.ts` using archiver, chunked fetching (200/chunk), MAX_ALL_RESULTS=10000
- **Guardrails**: Kill switch capsule redaction in JSONL, server-side 409 confirm protocol, auth required, 1hr job expiry
- **409 Confirm Protocol**: First POST without `confirm` → 409 CONFIRM_REQUIRED with `riskCounts` (piiCount, killCount); second POST with `confirm:true` → queues job
- **Snapshot Boundary**: `requestedAt` timestamp stored at job creation; all queries use `beforeDate` to prevent drift during chunked fetching
- **Manifest Fields**: requestedAt, generatedAt, capApplied, capLimit (10000), expiresAt
- **Frontend**: Export dropdown on /receipts ("Export this page" / "Export all results"), server-driven confirm dialog, polling for status, toast with download button
- **Request Schema**: Zod validated via bulkExportRequestSchema (scope, page, pageSize, status, q, hasForensics, killSwitch, confirm)

## P9-6 Backend Pagination (Completed)
- **Paged Endpoint**: `GET /api/receipts/paged` with server-side filtering, sorting, pagination
- **Query Params**: page, pageSize (max 200), status, q (search), hasForensics, killSwitch, order (asc/desc)
- **Response**: `{ items, total, page, pageSize, totalPages }` with page clamped to valid range
- **DB Indexes**: idx_receipts_created_at, idx_receipts_verification_status, idx_receipts_kill_switch, idx_receipts_receipt_id
- **Frontend**: Debounced search (300ms), status/forensics/killSwitch filters, page size selector (50/100/200), prev/next navigation
- **Validation**: Strict boolean parsing for hasForensics/killSwitch (400 on invalid), status validated against enum
- **Tests**: 34 table tests (7 new pagination tests), all 69 tests passing

## P9-5 Ops Hardening (Completed)
- **Row Virtualization**: /receipts uses @tanstack/react-virtual for O(viewport) rendering
- **Memoized Forensics**: forensicsCache Map avoids re-parsing per render
- **useCallback**: Badge renderers, sort, copy, export handlers all memoized
- **Last Updated + Refresh**: Header shows data fetch timestamp + manual refresh button
- **Auth Banner**: Reusable AuthRequiredBanner component used across receipts, receipt-detail, sensors
- **Export Safety**: AlertDialog confirms export when PII detected or kill switch engaged
- **apiFetch Contract Tests**: 10 tests for injection behavior (no prod, no public, e2e throw)
- **Perf Smoke Tests**: 15 tests (virtualization structure, 5k/10k synthetic rows, parsing/filter/sort benchmarks)

## Running the Application
The application runs on port 5000 via the "Start application" workflow.
