// COPILOT TASK: Implement Gate 0 LLM wrapper for HALO
//
// FILE: server/llm/invokeLLMWithHalo.ts
//
// PURPOSE
// This is the single choke point for all LLM calls in the system.
// It captures raw upstream request + raw upstream response BEFORE
// any parsing, tagging, or ELI processing.
//
// This enables:
// - Non-repudiation (HALO transcript signing)
// - Model provenance (which model, when, how)
// - Enterprise auditing proxy capability later
//
// DO NOT ADD BUSINESS LOGIC HERE.
// This file is strictly a transport + provenance wrapper.

import { createHash, randomUUID } from "crypto";

// =============================================================================
// CANONICAL JSON HASHING
// Recursively sort object keys before JSON.stringify, then SHA-256 hex digest
// =============================================================================

function sortedKeysStringify(obj: unknown): string {
  if (obj === null || typeof obj !== "object") {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return "[" + obj.map(sortedKeysStringify).join(",") + "]";
  }
  const keys = Object.keys(obj as Record<string, unknown>).sort();
  return (
    "{" +
    keys
      .map(
        (k) =>
          JSON.stringify(k) +
          ":" +
          sortedKeysStringify((obj as Record<string, unknown>)[k])
      )
      .join(",") +
    "}"
  );
}

function canonicalHash(obj: unknown): string {
  return createHash("sha256")
    .update(sortedKeysStringify(obj), "utf8")
    .digest("hex");
}

// =============================================================================
// OUTPUT TEXT EXTRACTION (after hashing rawResponse — never before)
// =============================================================================

function extractOutputText(rawResponse: unknown): string {
  const r = rawResponse as Record<string, unknown>;

  // chat.completions style: choices[0].message.content
  const choices = r?.choices as Array<Record<string, unknown>> | undefined;
  const firstChoice = Array.isArray(choices) ? choices[0] : undefined;
  const message = firstChoice?.message as Record<string, unknown> | undefined;
  if (typeof message?.content === "string") {
    return message.content;
  }

  // responses style: collect output_text blocks
  const output = r?.output as Array<Record<string, unknown>> | undefined;
  if (Array.isArray(output)) {
    const texts = output
      .filter((b) => b.type === "output_text" || b.text != null)
      .map((b) => (b.text as string | undefined) ?? (b.output_text as string | undefined) ?? "");
    if (texts.length > 0) {
      return texts.join("\n");
    }
  }

  // Fallback
  return JSON.stringify(rawResponse);
}

// =============================================================================
// MAIN EXPORT
// =============================================================================

export async function invokeLLMWithHalo(
  deps: { haloSignTranscript: (transcript: unknown) => Promise<unknown> },
  input: {
    model?: string;
    requestPayload: Record<string, unknown>; // EXACT body sent upstream
    generationParams?: unknown;
    receiptId?: string;
    userId?: string;
    tenantId?: string;
  }
): Promise<{
  rawResponse: unknown;
  outputText: string;
  provenance: Record<string, unknown>;
  haloReceipt: unknown;
}> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not configured");
  }

  const baseUrl = process.env.OPENAI_BASE_URL ?? "https://api.openai.com/v1";
  const model = input.model ?? process.env.LLM_MODEL ?? "gpt-4o";

  // Endpoint logic: if requestPayload.__endpoint exists, use it; otherwise "/responses"
  const endpoint =
    typeof input.requestPayload.__endpoint === "string"
      ? input.requestPayload.__endpoint
      : "/responses";

  // Build request body without mutating input.requestPayload
  const { __endpoint: _endpointKey, ...payloadWithoutEndpoint } = input.requestPayload;
  const requestBody: Record<string, unknown> = { ...payloadWithoutEndpoint, model };

  // Build request envelope (hashed before upstream call)
  const requestEnvelope: Record<string, unknown> = {
    endpoint,
    body: requestBody,
    model,
    receiptId: input.receiptId ?? null,
    userId: input.userId ?? null,
    tenantId: input.tenantId ?? null,
  };

  const requestEnvelopeHash = canonicalHash(requestEnvelope);

  // Call upstream provider
  const response = await fetch(`${baseUrl}${endpoint}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    throw new Error(
      `LLM provider error: ${response.status} ${response.statusText}`
    );
  }

  // Capture rawResponse BEFORE any mutation or text extraction
  const rawResponse: unknown = await response.json();
  const rawResponseHash = canonicalHash(rawResponse);

  // Extract output text AFTER hashing rawResponse
  const outputText = extractOutputText(rawResponse);

  const ts = new Date().toISOString();
  const invocationId = randomUUID();

  const provenanceBase: Record<string, unknown> = {
    invocation_id: invocationId,
    model,
    endpoint,
    request_hash: requestEnvelopeHash,
    response_hash: rawResponseHash,
    receipt_id: input.receiptId ?? null,
    user_id: input.userId ?? null,
    tenant_id: input.tenantId ?? null,
    ts,
  };

  // provenance_hash = sha256(canonicalize(provenanceBase))
  const provenanceHash = canonicalHash(provenanceBase);

  const provenance: Record<string, unknown> = {
    ...provenanceBase,
    provenance_hash: provenanceHash,
  };

  // Transcript shape passed to signer
  const transcript = {
    request: requestEnvelope,
    response: rawResponse,
    provenance,
  };

  const haloReceipt = await deps.haloSignTranscript(transcript);

  return {
    rawResponse,
    outputText,
    provenance,
    haloReceipt,
  };
}

// =============================================================================
// GEMINI ADAPTER STUB (Phase 1: not implemented)
// =============================================================================

export async function invokeGemini(
  _deps: unknown,
  _input: unknown
): Promise<never> {
  throw new Error("Gemini not implemented");
}
