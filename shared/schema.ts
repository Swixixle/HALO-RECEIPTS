import { sql } from "drizzle-orm";
import { pgTable, text, integer, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// Database Tables

export const receipts = pgTable("receipts", {
  id: text("id").primaryKey(),
  receiptId: text("receipt_id").notNull().unique(),
  platform: text("platform").notNull(),
  capturedAt: text("captured_at").notNull(),
  rawJson: text("raw_json").notNull(),
  forensicsJson: text("forensics_json"),
  expectedHashSha256: text("expected_hash_sha256").notNull(),
  computedHashSha256: text("computed_hash_sha256").notNull(),
  hashMatch: integer("hash_match").notNull().default(0),
  signatureStatus: text("signature_status").notNull(),
  signatureReason: text("signature_reason"),
  signatureIssuerId: text("signature_issuer_id"),
  signatureIssuerLabel: text("signature_issuer_label"),
  signatureKeyStatus: text("signature_key_status"),
  chainStatus: text("chain_status"),
  previousReceiptId: text("previous_receipt_id"),
  receiptHashSha256: text("receipt_hash_sha256"),
  verificationStatus: text("verification_status").notNull(),
  verifiedAt: text("verified_at").notNull(),
  verificationEngineId: text("verification_engine_id").notNull(),
  immutableLock: integer("immutable_lock").notNull().default(0),
  hindsightKillSwitch: integer("hindsight_kill_switch").notNull().default(0),
  createdAt: text("created_at").notNull(),
});

export const interpretations = pgTable("interpretations", {
  id: text("id").primaryKey(),
  receiptId: text("receipt_id").notNull(),
  modelId: text("model_id").notNull(),
  kind: text("kind").notNull(),
  content: text("content").notNull(),
  createdAt: text("created_at").notNull(),
  verificationStatusAtTime: text("verification_status_at_time").notNull(),
  hashAtTime: text("hash_at_time").notNull(),
});

// P5: Research Dataset Records (anonymized, no PII, no transcripts)
// DO NOT store: receipt_id, transcript, hashes, keys, exact timestamps
export const researchRecords = pgTable("research_records", {
  // Fresh UUID, NOT correlated to receipt_id
  researchId: text("research_id").primaryKey(),
  
  // Schema version
  datasetVersion: text("dataset_version").notNull(),
  
  // Time buckets (day-level only)
  captureDateBucket: text("capture_date_bucket").notNull(),
  verificationDateBucket: text("verification_date_bucket").notNull(),
  
  // Categorical outcomes
  platformCategory: text("platform_category").notNull(),
  verificationOutcome: text("verification_outcome").notNull(),
  signatureOutcome: text("signature_outcome").notNull(),
  chainOutcome: text("chain_outcome").notNull(),
  
  // JSON fields for structured data
  structuralStats: text("structural_stats").notNull(), // JSON
  anomalyIndicators: text("anomaly_indicators").notNull(), // JSON
  riskCategories: text("risk_categories").notNull(), // JSON
  piiPresence: text("pii_presence").notNull(), // JSON
  
  // Boolean flags
  killSwitchEngaged: integer("kill_switch_engaged").notNull().default(0),
  
  // Bucketed interpretation count
  interpretationBucket: text("interpretation_bucket").notNull(),
  
  // Consent tracking (JSON)
  consentScope: text("consent_scope").notNull(), // JSON
  
  // Record creation (day-level only for privacy)
  createdAtBucket: text("created_at_bucket").notNull(),
});

// P6: LLM Observations (SENSOR MODE ONLY - never affects verification)
// LLMs observe and describe, they NEVER judge truth/validity
// This data is ISOLATED from verification/forensics/research
export const llmObservations = pgTable("llm_observations", {
  observationId: text("observation_id").primaryKey(),
  receiptId: text("receipt_id").notNull(),
  modelId: text("model_id").notNull(),
  observationType: text("observation_type").notNull(),
  basedOn: text("based_on").notNull(), // submitted_transcript | verified_transcript
  content: text("content").notNull(),
  confidenceStatement: text("confidence_statement").notNull(),
  limitations: text("limitations").notNull(), // JSON array
  createdAt: text("created_at").notNull(),
});

// Bulk Export Jobs
export const exportJobs = pgTable("export_jobs", {
  exportId: text("export_id").primaryKey(),
  status: text("status").notNull().default("QUEUED"),
  scope: text("scope").notNull(),
  filtersJson: text("filters_json").notNull(),
  total: integer("total").notNull().default(0),
  completed: integer("completed").notNull().default(0),
  filePath: text("file_path"),
  errorMessage: text("error_message"),
  createdAt: text("created_at").notNull(),
  expiresAt: text("expires_at").notNull(),
});

export type ExportJob = typeof exportJobs.$inferSelect;
export type InsertExportJob = typeof exportJobs.$inferInsert;

// Bulk export request schema
export const bulkExportRequestSchema = z.object({
  scope: z.enum(["current_page", "all_results"]),
  page: z.number().int().min(1).optional(),
  pageSize: z.number().int().min(1).max(200).optional(),
  status: z.string().optional(),
  q: z.string().optional(),
  hasForensics: z.boolean().optional(),
  killSwitch: z.boolean().optional(),
  confirm: z.boolean().optional(),
});

export type BulkExportRequest = z.infer<typeof bulkExportRequestSchema>;

// Zod Schemas for API validation

// Message in transcript - permissive to allow forensics to detect anomalies
// Role accepts any string so unexpected roles can be detected by structural_anomalies detector
// Content accepts any string including empty so empty_content can be detected
export const messageSchema = z.object({
  role: z.string(),
  content: z.string(),
  timestamp: z.string().optional(),
});

// Transcript object
// Note: canonicalization accepts any string to allow route-level UNKNOWN_CANONICALIZATION rejection
export const transcriptSchema = z.object({
  embedded: z.boolean(),
  canonicalization: z.string(),
  messages: z.array(messageSchema),
});

// Signature object
export const signatureSchema = z.object({
  alg: z.string().optional(),
  public_key_id: z.string().optional(),
  value: z.string().optional(),
}).optional();

// Receipt capsule schema (input)
export const receiptCapsuleSchema = z.object({
  schema: z.literal("ai-receipt/1.0"),
  receipt_id: z.string(),
  platform: z.string(),
  captured_at: z.string(),
  capture_agent: z.string(),
  transcript: transcriptSchema,
  transcript_hash_sha256: z.string(),
  signature: signatureSchema,
  previous_receipt_hash_sha256: z.string().optional(),
  public_verify_url: z.string().optional(),
}).passthrough();

// P5: Research consent scope
export const researchConsentScopeSchema = z.object({
  anonymized_statistics: z.boolean().default(false),
  model_behavior_research: z.boolean().default(false),
  academic_publication: z.boolean().default(false),
  commercial_datasets: z.boolean().default(false),
});

// Verify request options
export const verifyOptionsSchema = z.object({
  verify_signature: z.boolean().default(true),
  verify_chain: z.boolean().default(false),
  key_registry_mode: z.enum(["allow_untrusted", "require_trusted"]).default("allow_untrusted"),
  // P5: Research consent (opt-in only)
  research_consent: researchConsentScopeSchema.optional(),
});

// Verify request schema (API input)
export const verifyRequestSchema = z.object({
  schema: z.literal("ai-receipt/verify-request/1.0"),
  request_id: z.string().optional(),
  receipt_capsule: receiptCapsuleSchema,
  options: verifyOptionsSchema.optional(),
});

// Interpret request schema
export const interpretRequestSchema = z.object({
  schema: z.literal("ai-receipt/interpret-request/1.0"),
  model_id: z.string(),
  prompt_mode: z.string().default("forensic"),
  question: z.string(),
  kind: z.enum(["fact", "interpretation", "uncertainty"]),
});

// Types
export type Receipt = typeof receipts.$inferSelect;
export type InsertReceipt = typeof receipts.$inferInsert;
export type Interpretation = typeof interpretations.$inferSelect;
export type InsertInterpretation = typeof interpretations.$inferInsert;

export type Message = z.infer<typeof messageSchema>;
export type Transcript = z.infer<typeof transcriptSchema>;
export type ReceiptCapsule = z.infer<typeof receiptCapsuleSchema>;
export type VerifyRequest = z.infer<typeof verifyRequestSchema>;
export type VerifyOptions = z.infer<typeof verifyOptionsSchema>;
export type InterpretRequest = z.infer<typeof interpretRequestSchema>;

// Verify result types (API output)
export interface VerifyResult {
  schema: "ai-receipt/verify-result/1.0";
  request_id: string;
  receipt_id: string;
  verification_engine: {
    engine_id: string;
    verified_at: string;
  };
  integrity: {
    canonicalization: "c14n-v1";
    canonical_transcript: string;
    computed_hash_sha256: string;
    expected_hash_sha256: string;
    hash_match: boolean;
    c14n_summary: {
      c14n_version: "c14n-v1";
      fields_hashed: string[];
      message_count_hashed: number;
      hash_input_bytes: number;
    };
  };
  signature: {
    alg: string;
    public_key_id: string;
    status: "VALID" | "INVALID" | "UNTRUSTED_ISSUER" | "NO_SIGNATURE";
    reason: string;
    issuer_id?: string;
    issuer_label?: string;
    key_status?: "ACTIVE" | "REVOKED" | "EXPIRED";
    trusted?: boolean;
  };
  chain: {
    checked: boolean;
    status: "NOT_CHECKED" | "GENESIS" | "LINKED" | "BROKEN";
    reason: string;
    previous_receipt_id?: string;
    expected_previous_hash?: string;
    observed_previous_hash?: string;
    link_match?: boolean;
  };
  receipt_hash_sha256: string;
  verification_status: "VERIFIED" | "PARTIALLY_VERIFIED" | "UNVERIFIED";
  failure_modes: Array<{ code: string; message: string }>;
  forensics?: ForensicsResult;
}

// Tri-sensor result type
export interface TriSensorResult {
  interpreter: { output: string; available: boolean };
  summarizer: { output: string; available: boolean };
  claimExtractor: { output: string; available: boolean };
  disagreement_detected: boolean;
}

// Forensics types (deterministic detectors)
export interface ForensicsResult {
  schema: "ai-receipt/forensics/1.0";
  forensics_engine_id: string;
  forensics_ran_at: string;
  detectors_ran: string[];
  based_on: "verified_transcript" | "submitted_payload";
  integrity_context: "VERIFIED" | "PARTIALLY_VERIFIED" | "UNVERIFIED";
  transcript_stats: {
    message_count: number;
    roles: { user: number; assistant: number; system: number; tool: number; other: number };
    chars_total: number;
    chars_by_role: { user: number; assistant: number; system: number; tool: number; other: number };
    avg_chars_per_message: number;
    max_message_chars: number;
    max_message_role: string;
  };
  timestamp_checks: {
    present: boolean;
    missing_count: number;
    non_iso_count: number;
    non_monotonic_count: number;
    notes: string[];
  };
  content_signals: {
    code_fence_count: number;
    url_count: number;
    newline_count_total: number;
    non_printable_char_count: number;
    high_entropy_block_count: number;
    high_entropy_config: {
      method: string;
      description: string;
      min_block_length: number;
      pattern: string;
    };
  };
  risk_keywords: {
    instructional: { present: boolean; count: number };
    medical: { present: boolean; count: number };
    legal: { present: boolean; count: number };
    financial: { present: boolean; count: number };
    self_harm: { present: boolean; count: number };
  };
  pii_heuristics: {
    email_like_count: number;
    phone_like_count: number;
    ssn_like_count: number;
    dob_like_count: number;
    mrn_like_count: number;
    ip_like_count: number;
    notes: string[];
  };
  structural_anomalies: {
    missing_role_count: number;
    empty_content_count: number;
    unexpected_role_count: number;
    duplicate_message_count: number;
    oversize_message_count: number;
    oversize_threshold_chars: number;
    anomalies: Array<{
      code: "MISSING_ROLE" | "EMPTY_CONTENT" | "UNEXPECTED_ROLE" | "DUPLICATE_MESSAGE" | "OVERSIZE_MESSAGE";
      severity: "LOW" | "MEDIUM" | "HIGH";
      message: string;
      index?: number;
      observed?: {
        role?: string;
        content_length?: number;
        threshold?: number;
      };
    }>;
  };
  anomalies: Array<{
    code: string;
    severity: "LOW" | "MEDIUM" | "HIGH";
    message: string;
  }>;
}

// Export report types
export interface ExportReport {
  schema: "ai-receipt/export/1.0";
  receipt_id: string;
  exported_at: string;
  export_mode: "full" | "redacted" | "hidden";
  capsule_raw_json?: string;
  verify_result: VerifyResult;
  forensics: ForensicsResult;
  interpretations: Interpretation[];
}
