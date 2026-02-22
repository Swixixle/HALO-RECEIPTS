import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { haloSignTranscript, _resetReceiptSigningKeyForTest } from "../llm/haloSignTranscript";

// =============================================================================
// Helpers
// =============================================================================

function saveEnv(...keys: string[]): Record<string, string | undefined> {
  const saved: Record<string, string | undefined> = {};
  for (const key of keys) saved[key] = process.env[key];
  return saved;
}

function restoreEnv(saved: Record<string, string | undefined>): void {
  for (const [key, val] of Object.entries(saved)) {
    if (val === undefined) delete process.env[key];
    else process.env[key] = val;
  }
}

const ENV_KEYS = ["NODE_ENV", "RECEIPT_SIGNING_KEY", "RECEIPT_VERIFY_KEY", "RECEIPT_KEY_ID"];

// =============================================================================
// Tests
// =============================================================================

describe("haloSignTranscript — production key enforcement", () => {
  let saved: Record<string, string | undefined>;

  beforeEach(() => {
    saved = saveEnv(...ENV_KEYS);
    _resetReceiptSigningKeyForTest();
    delete process.env.RECEIPT_SIGNING_KEY;
    delete process.env.RECEIPT_VERIFY_KEY;
    delete process.env.RECEIPT_KEY_ID;
  });

  afterEach(() => {
    restoreEnv(saved);
    _resetReceiptSigningKeyForTest();
  });

  it("throws in production when RECEIPT_SIGNING_KEY is missing", async () => {
    process.env.NODE_ENV = "production";
    await expect(haloSignTranscript({ test: true })).rejects.toThrow(
      "Production requires RECEIPT_SIGNING_KEY"
    );
  });

  it("throws in production when only RECEIPT_SIGNING_KEY is set (missing others)", async () => {
    process.env.NODE_ENV = "production";
    process.env.RECEIPT_SIGNING_KEY = "some-key";
    // RECEIPT_VERIFY_KEY and RECEIPT_KEY_ID still missing
    await expect(haloSignTranscript({ test: true })).rejects.toThrow(
      "Production requires RECEIPT_SIGNING_KEY"
    );
  });

  it("does NOT throw in development when keys are missing (ephemeral key is used)", async () => {
    process.env.NODE_ENV = "development";
    await expect(haloSignTranscript({ test: true })).resolves.toMatchObject({
      signature_alg: "Ed25519",
      public_key_id: expect.stringContaining("receipt-ephemeral-dev-"),
    });
  });

  it("ephemeral key_id contains 'dev' to clearly indicate non-production origin", async () => {
    process.env.NODE_ENV = "development";
    const receipt = await haloSignTranscript({ test: true });
    expect(receipt.public_key_id).toMatch(/receipt-ephemeral-dev-/);
  });

  it("uses configured keys in production when all three env vars are set", async () => {
    // Generate a real ed25519 key pair to use as configured keys
    const { generateKeyPairSync } = await import("crypto");
    const { publicKey, privateKey } = generateKeyPairSync("ed25519");
    const publicKeyPem = publicKey.export({ type: "spki", format: "pem" }) as string;
    const privateKeyPem = privateKey.export({ type: "pkcs8", format: "pem" }) as string;

    process.env.NODE_ENV = "production";
    process.env.RECEIPT_SIGNING_KEY = privateKeyPem;
    process.env.RECEIPT_VERIFY_KEY = publicKeyPem;
    process.env.RECEIPT_KEY_ID = "prod-key-001";

    const receipt = await haloSignTranscript({ test: true });
    expect(receipt.public_key_id).toBe("prod-key-001");
    expect(receipt.signature_alg).toBe("Ed25519");
  });
});

describe("haloSignTranscript — receipt structure", () => {
  let saved: Record<string, string | undefined>;

  beforeEach(() => {
    saved = saveEnv(...ENV_KEYS);
    _resetReceiptSigningKeyForTest();
    process.env.NODE_ENV = "development";
    delete process.env.RECEIPT_SIGNING_KEY;
    delete process.env.RECEIPT_VERIFY_KEY;
    delete process.env.RECEIPT_KEY_ID;
  });

  afterEach(() => {
    restoreEnv(saved);
    _resetReceiptSigningKeyForTest();
  });

  it("returns all required receipt fields", async () => {
    const receipt = await haloSignTranscript({ hello: "world" });
    expect(receipt).toMatchObject({
      id: expect.any(String),
      ts: expect.any(String),
      transcript_hash: expect.stringMatching(/^[0-9a-f]{64}$/),
      signature: expect.any(String),
      signature_alg: "Ed25519",
      public_key_id: expect.any(String),
      signed_payload: expect.any(String),
    });
  });

  it("transcript_hash changes when transcript content changes", async () => {
    const r1 = await haloSignTranscript({ a: 1 });
    const r2 = await haloSignTranscript({ a: 2 });
    expect(r1.transcript_hash).not.toBe(r2.transcript_hash);
  });
});
