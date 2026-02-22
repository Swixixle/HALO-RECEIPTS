import { describe, it, expect } from "vitest";
import { HALO_RECEIPTS_CONTRACT } from "../integration-contract";

describe("HALO_RECEIPTS_CONTRACT — contract surface", () => {
  it("exports a contractVersion string", () => {
    expect(typeof HALO_RECEIPTS_CONTRACT.contractVersion).toBe("string");
    expect(HALO_RECEIPTS_CONTRACT.contractVersion).toBe("1.0.0");
  });

  it("exports invokeLLMWithHalo as a function", () => {
    expect(typeof HALO_RECEIPTS_CONTRACT.invokeLLMWithHalo).toBe("function");
  });

  it("exports haloSignTranscript as a function", () => {
    expect(typeof HALO_RECEIPTS_CONTRACT.haloSignTranscript).toBe("function");
  });

  it("exports verifyTranscriptReceipt as a function", () => {
    expect(typeof HALO_RECEIPTS_CONTRACT.verifyTranscriptReceipt).toBe("function");
  });

  it("verifyTranscriptReceipt returns ok:true when hash matches", async () => {
    const transcript = { hello: "world" };
    const receipt = await HALO_RECEIPTS_CONTRACT.haloSignTranscript(transcript);
    const result = HALO_RECEIPTS_CONTRACT.verifyTranscriptReceipt(transcript, receipt);
    expect(result.ok).toBe(true);
    expect(result.errors).toBeUndefined();
  });

  it("verifyTranscriptReceipt returns ok:false when transcript is tampered", async () => {
    const transcript = { hello: "world" };
    const receipt = await HALO_RECEIPTS_CONTRACT.haloSignTranscript(transcript);
    const tamperedTranscript = { hello: "tampered" };
    const result = HALO_RECEIPTS_CONTRACT.verifyTranscriptReceipt(tamperedTranscript, receipt);
    expect(result.ok).toBe(false);
    expect(result.errors).toBeDefined();
    expect(result.errors!.length).toBeGreaterThan(0);
    expect(result.errors![0]).toMatch(/transcript_hash mismatch/);
  });

  it("verifyTranscriptReceipt does not throw on malformed receipt", () => {
    const transcript = { hello: "world" };
    const badReceipt = {
      id: "x",
      ts: "2024-01-01T00:00:00.000Z",
      transcript_hash: "deadbeef",
      signature: "badsig==",
      signature_alg: "Ed25519" as const,
      public_key_id: "key",
      signed_payload: "{}",
    };
    expect(() =>
      HALO_RECEIPTS_CONTRACT.verifyTranscriptReceipt(transcript, badReceipt)
    ).not.toThrow();
    const result = HALO_RECEIPTS_CONTRACT.verifyTranscriptReceipt(transcript, badReceipt);
    expect(result.ok).toBe(false);
  });
});
