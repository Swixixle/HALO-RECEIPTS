import { generateKeyPairSync, randomUUID, sign } from "crypto";
import { stableStringifyStrict, sha256Hex } from "../audit-canon";

// ---------------------------------------------------------------------------
// Receipt-specific signing key
// Separate from checkpoint keys — different subject, lifecycle, and key policy.
// Configure via RECEIPT_SIGNING_KEY / RECEIPT_VERIFY_KEY / RECEIPT_KEY_ID.
// Falls back to a per-process ephemeral key when env vars are absent.
// ---------------------------------------------------------------------------

interface ReceiptKeyPair {
  publicKeyId: string;
  publicKeyPem: string;
  privateKeyPem: string;
}

let activeReceiptKey: ReceiptKeyPair | null = null;

function getOrCreateReceiptSigningKey(): ReceiptKeyPair {
  if (activeReceiptKey) return activeReceiptKey;

  const envPrivate = process.env.RECEIPT_SIGNING_KEY;
  const envPublic = process.env.RECEIPT_VERIFY_KEY;
  const envKeyId = process.env.RECEIPT_KEY_ID;

  if (envPrivate && envPublic && envKeyId) {
    activeReceiptKey = { publicKeyId: envKeyId, publicKeyPem: envPublic, privateKeyPem: envPrivate };
    return activeReceiptKey;
  }

  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  const publicKeyPem = publicKey.export({ type: "spki", format: "pem" }) as string;
  const privateKeyPem = privateKey.export({ type: "pkcs8", format: "pem" }) as string;
  const publicKeyId = `receipt-ephemeral-${sha256Hex(publicKeyPem).slice(0, 32)}`;

  activeReceiptKey = { publicKeyId, publicKeyPem, privateKeyPem };

  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    level: "warn",
    event: "receipt.key.ephemeral",
    publicKeyId,
    message: "Generated ephemeral receipt-signing key. Set RECEIPT_SIGNING_KEY, RECEIPT_VERIFY_KEY, RECEIPT_KEY_ID for persistent signing.",
  }));

  return activeReceiptKey;
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
  const keyPair = getOrCreateReceiptSigningKey();
  const canonical = stableStringifyStrict(transcript);
  const transcript_hash = sha256Hex(canonical);
  const ts = new Date().toISOString();

  const signingPayload = stableStringifyStrict({
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
