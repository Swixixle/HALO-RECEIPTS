import { createHash, randomUUID, sign } from "crypto";
import { getOrCreateCheckpointKey } from "../checkpoint-signer";

// Canonical JSON: recursively sort object keys, then serialize
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

export interface HaloTranscriptReceipt {
  id: string;
  ts: string;
  transcript_hash: string;
  signature: string;
  signature_alg: "Ed25519";
  public_key_id: string;
  signed_payload: string;
}

export async function haloSignTranscript(
  transcript: unknown
): Promise<HaloTranscriptReceipt> {
  const keyPair = getOrCreateCheckpointKey();
  const canonical = sortedKeysStringify(transcript);
  const transcript_hash = createHash("sha256")
    .update(canonical, "utf8")
    .digest("hex");
  const ts = new Date().toISOString();

  const signingPayload = sortedKeysStringify({
    kid: keyPair.publicKeyId,
    transcript_hash,
    ts,
  });

  const sig = sign(
    null,
    Buffer.from(signingPayload, "utf8"),
    keyPair.privateKeyPem
  );

  return {
    id: randomUUID(),
    ts,
    transcript_hash,
    signature: sig.toString("base64"),
    signature_alg: "Ed25519",
    public_key_id: keyPair.publicKeyId,
    signed_payload: signingPayload,
  };
}
