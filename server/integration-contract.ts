import { verify } from "crypto";
import { stableStringifyStrict, sha256Hex } from "./audit-canon";
import { haloSignTranscript, type HaloTranscriptReceipt } from "./llm/haloSignTranscript";
import { invokeLLMWithHalo } from "./llm/invokeLLMWithHalo";

export interface VerifyTranscriptReceiptResult {
  ok: boolean;
  errors?: string[];
}

/**
 * Verify a HaloTranscriptReceipt.
 * - Recomputes transcript_hash and compares to receipt.transcript_hash.
 * - If RECEIPT_VERIFY_KEY is set, verifies the Ed25519 signature.
 * - Never throws; returns { ok: false, errors: [...] } on failure.
 */
export function verifyTranscriptReceipt(
  transcript: unknown,
  receipt: HaloTranscriptReceipt
): VerifyTranscriptReceiptResult {
  const errors: string[] = [];

  try {
    const canonical = stableStringifyStrict(transcript);
    const expectedHash = sha256Hex(canonical);
    if (expectedHash !== receipt.transcript_hash) {
      errors.push(
        `transcript_hash mismatch: expected ${expectedHash}, got ${receipt.transcript_hash}`
      );
    }
  } catch (err) {
    errors.push(
      `transcript_hash recomputation failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  const verifyKey = process.env.RECEIPT_VERIFY_KEY;
  if (verifyKey) {
    try {
      const isValid = verify(
        null,
        Buffer.from(receipt.signed_payload, "utf8"),
        verifyKey,
        Buffer.from(receipt.signature, "base64")
      );
      if (!isValid) {
        errors.push("Ed25519 signature verification failed");
      }
    } catch (err) {
      errors.push(
        `signature verification error: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  return errors.length === 0 ? { ok: true } : { ok: false, errors };
}

export const HALO_RECEIPTS_CONTRACT = {
  contractVersion: "1.0.0",
  invokeLLMWithHalo,
  haloSignTranscript,
  verifyTranscriptReceipt,
} as const;
