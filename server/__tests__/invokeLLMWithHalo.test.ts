import { describe, it, expect, vi, beforeEach } from "vitest";
import { invokeLLMWithHalo, invokeGemini } from "../llm/invokeLLMWithHalo";

// =============================================================================
// Helpers
// =============================================================================

function makeDeps(receiptOverride?: Partial<{ id: string; ts: string; transcript_hash: string; signature: string; signature_alg: "Ed25519"; public_key_id: string; signed_payload: string }>) {
  return {
    haloSignTranscript: vi.fn().mockResolvedValue({
      id: "test-receipt-id",
      ts: "2024-01-01T00:00:00.000Z",
      transcript_hash: "abc123",
      signature: "sig==",
      signature_alg: "Ed25519" as const,
      public_key_id: "test-key",
      signed_payload: "{}",
      ...receiptOverride,
    }),
  };
}

function mockFetchResponse(body: unknown, ok = true, status = 200) {
  return vi.fn().mockResolvedValue({
    ok,
    status,
    statusText: ok ? "OK" : "Error",
    json: vi.fn().mockResolvedValue(body),
  });
}

// =============================================================================
// Tests
// =============================================================================

describe("invokeLLMWithHalo", () => {
  beforeEach(() => {
    process.env.OPENAI_API_KEY = "test-key-123";
    process.env.OPENAI_BASE_URL = "https://api.openai.com/v1";
    vi.unstubAllGlobals();
  });

  describe("OPENAI_API_KEY requirement", () => {
    it("throws if OPENAI_API_KEY is not set", async () => {
      delete process.env.OPENAI_API_KEY;
      await expect(
        invokeLLMWithHalo(makeDeps(), { requestPayload: { messages: [] } })
      ).rejects.toThrow("OPENAI_API_KEY is not configured");
    });
  });

  describe("output text extraction", () => {
    it("extracts content from chat.completions style response", async () => {
      const chatResponse = {
        choices: [{ message: { content: "Hello from chat completions" } }],
      };
      vi.stubGlobal("fetch", mockFetchResponse(chatResponse));

      const result = await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [{ role: "user", content: "hi" }] },
      });

      expect(result.outputText).toBe("Hello from chat completions");
    });

    it("collects text blocks from responses style response", async () => {
      const responsesStyle = {
        output: [
          { type: "output_text", text: "First block" },
          { type: "output_text", text: "Second block" },
        ],
      };
      vi.stubGlobal("fetch", mockFetchResponse(responsesStyle));

      const result = await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
      });

      expect(result.outputText).toBe("First block\nSecond block");
    });

    it("falls back to JSON.stringify for unknown response shape", async () => {
      const unknownShape = { foo: "bar", baz: 42 };
      vi.stubGlobal("fetch", mockFetchResponse(unknownShape));

      const result = await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
      });

      expect(result.outputText).toBe(JSON.stringify(unknownShape));
    });
  });

  describe("endpoint selection", () => {
    it("uses __endpoint from requestPayload if present", async () => {
      let capturedUrl = "";
      vi.stubGlobal("fetch", vi.fn().mockImplementation((url: string) => {
        capturedUrl = url;
        return Promise.resolve({
          ok: true,
          status: 200,
          statusText: "OK",
          json: () => Promise.resolve({ choices: [{ message: { content: "ok" } }] }),
        });
      }));

      await invokeLLMWithHalo(makeDeps(), {
        requestPayload: {
          __endpoint: "/chat/completions",
          messages: [],
        },
      });

      expect(capturedUrl).toContain("/chat/completions");
    });

    it("defaults to /responses endpoint when __endpoint is absent", async () => {
      let capturedUrl = "";
      vi.stubGlobal("fetch", vi.fn().mockImplementation((url: string) => {
        capturedUrl = url;
        return Promise.resolve({
          ok: true,
          status: 200,
          statusText: "OK",
          json: () => Promise.resolve({ choices: [{ message: { content: "ok" } }] }),
        });
      }));

      await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
      });

      expect(capturedUrl).toContain("/responses");
    });

    it("does not include __endpoint in the body sent upstream", async () => {
      let capturedBody: Record<string, unknown> = {};
      vi.stubGlobal("fetch", vi.fn().mockImplementation((_url: string, init: RequestInit) => {
        capturedBody = JSON.parse(init.body as string);
        return Promise.resolve({
          ok: true,
          status: 200,
          statusText: "OK",
          json: () => Promise.resolve({ choices: [{ message: { content: "ok" } }] }),
        });
      }));

      await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { __endpoint: "/chat/completions", messages: [] },
      });

      expect(capturedBody).not.toHaveProperty("__endpoint");
    });
  });

  describe("provenance structure", () => {
    it("includes required provenance fields", async () => {
      vi.stubGlobal("fetch", mockFetchResponse({ choices: [{ message: { content: "hi" } }] }));

      const result = await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
        receiptId: "receipt-123",
        userId: "user-456",
        tenantId: "tenant-789",
      });

      expect(result.provenance).toMatchObject({
        invocation_id: expect.any(String),
        model: expect.any(String),
        endpoint: expect.any(String),
        request_hash: expect.stringMatching(/^[0-9a-f]{64}$/),
        response_hash: expect.stringMatching(/^[0-9a-f]{64}$/),
        provenance_hash: expect.stringMatching(/^[0-9a-f]{64}$/),
        receipt_id: "receipt-123",
        user_id: "user-456",
        tenant_id: "tenant-789",
        ts: expect.any(String),
      });
    });

    it("provenance_hash is SHA-256 of canonical provenanceBase", async () => {
      const { createHash } = await import("crypto");
      vi.stubGlobal("fetch", mockFetchResponse({ choices: [{ message: { content: "hi" } }] }));

      const result = await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
      });

      // provenance without provenance_hash is provenanceBase
      const { provenance_hash, ...provenanceBase } = result.provenance;

      // Manually compute canonical hash of provenanceBase
      function sortedKeys(obj: unknown): string {
        if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
        if (Array.isArray(obj)) return "[" + obj.map(sortedKeys).join(",") + "]";
        const keys = Object.keys(obj as Record<string, unknown>).sort();
        return "{" + keys.map(k => JSON.stringify(k) + ":" + sortedKeys((obj as Record<string, unknown>)[k])).join(",") + "}";
      }
      const expectedHash = createHash("sha256").update(sortedKeys(provenanceBase), "utf8").digest("hex");
      expect(provenance_hash).toBe(expectedHash);
    });
  });

  describe("transcript shape passed to signer", () => {
    it("passes { request, response, provenance } to haloSignTranscript", async () => {
      const rawResponse = { choices: [{ message: { content: "signed" } }] };
      vi.stubGlobal("fetch", mockFetchResponse(rawResponse));
      const deps = makeDeps();

      await invokeLLMWithHalo(deps, { requestPayload: { messages: [] } });

      expect(deps.haloSignTranscript).toHaveBeenCalledOnce();
      const transcript = deps.haloSignTranscript.mock.calls[0][0] as Record<string, unknown>;
      expect(transcript).toHaveProperty("request");
      expect(transcript).toHaveProperty("response");
      expect(transcript).toHaveProperty("provenance");
    });

    it("response in transcript is exact rawResponse (not mutated)", async () => {
      const rawResponse = { choices: [{ message: { content: "exact" } }], id: "resp-001" };
      vi.stubGlobal("fetch", mockFetchResponse(rawResponse));
      const deps = makeDeps();

      await invokeLLMWithHalo(deps, { requestPayload: { messages: [] } });

      const transcript = deps.haloSignTranscript.mock.calls[0][0] as Record<string, unknown>;
      expect(transcript.response).toEqual(rawResponse);
    });
  });

  describe("rawResponse hashing order", () => {
    it("response_hash in provenance matches canonical hash of rawResponse", async () => {
      const { createHash } = await import("crypto");
      const rawResponse = { id: "resp-xyz", choices: [{ message: { content: "order test" } }] };
      vi.stubGlobal("fetch", mockFetchResponse(rawResponse));

      const result = await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
      });

      function sortedKeys(obj: unknown): string {
        if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
        if (Array.isArray(obj)) return "[" + obj.map(sortedKeys).join(",") + "]";
        const keys = Object.keys(obj as Record<string, unknown>).sort();
        return "{" + keys.map(k => JSON.stringify(k) + ":" + sortedKeys((obj as Record<string, unknown>)[k])).join(",") + "}";
      }
      const expectedHash = createHash("sha256").update(sortedKeys(rawResponse), "utf8").digest("hex");
      expect(result.provenance.response_hash).toBe(expectedHash);
    });
  });

  describe("model selection", () => {
    it("uses model from input if provided", async () => {
      let capturedBody: Record<string, unknown> = {};
      vi.stubGlobal("fetch", vi.fn().mockImplementation((_url: string, init: RequestInit) => {
        capturedBody = JSON.parse(init.body as string);
        return Promise.resolve({
          ok: true, status: 200, statusText: "OK",
          json: () => Promise.resolve({ choices: [{ message: { content: "ok" } }] }),
        });
      }));

      await invokeLLMWithHalo(makeDeps(), {
        model: "gpt-4-turbo",
        requestPayload: { messages: [] },
      });

      expect(capturedBody.model).toBe("gpt-4-turbo");
    });

    it("falls back to LLM_MODEL env var when model not specified", async () => {
      process.env.LLM_MODEL = "gpt-3.5-turbo";
      let capturedBody: Record<string, unknown> = {};
      vi.stubGlobal("fetch", vi.fn().mockImplementation((_url: string, init: RequestInit) => {
        capturedBody = JSON.parse(init.body as string);
        return Promise.resolve({
          ok: true, status: 200, statusText: "OK",
          json: () => Promise.resolve({ choices: [{ message: { content: "ok" } }] }),
        });
      }));

      await invokeLLMWithHalo(makeDeps(), {
        requestPayload: { messages: [] },
      });

      expect(capturedBody.model).toBe("gpt-3.5-turbo");
      delete process.env.LLM_MODEL;
    });
  });

  describe("provider errors", () => {
    it("throws on non-ok provider response", async () => {
      vi.stubGlobal("fetch", mockFetchResponse({}, false, 429));

      await expect(
        invokeLLMWithHalo(makeDeps(), { requestPayload: { messages: [] } })
      ).rejects.toThrow("LLM provider error: 429");
    });
  });

  describe("return shape", () => {
    it("returns rawResponse, outputText, provenance, haloReceipt", async () => {
      const rawResponse = { choices: [{ message: { content: "result" } }] };
      vi.stubGlobal("fetch", mockFetchResponse(rawResponse));
      const deps = makeDeps();

      const result = await invokeLLMWithHalo(deps, {
        requestPayload: { messages: [] },
      });

      expect(result).toHaveProperty("rawResponse");
      expect(result).toHaveProperty("outputText", "result");
      expect(result).toHaveProperty("provenance");
      expect(result).toHaveProperty("haloReceipt");
    });
  });
});

describe("invokeGemini", () => {
  it("throws 'Gemini not implemented'", async () => {
    await expect(invokeGemini(null, null)).rejects.toThrow(
      "Gemini not implemented"
    );
  });
});
