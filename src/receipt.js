import crypto from "node:crypto";

/**
 * Deterministic JSON stringify:
 * - Sorts object keys (recursively)
 * - Ensures stable hashing across runs
 */
export function stableStringify(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);

  if (Array.isArray(value)) {
    return "[" + value.map(stableStringify).join(",") + "]";
  }

  const keys = Object.keys(value).sort();
  const body = keys
    .map((k) => JSON.stringify(k) + ":" + stableStringify(value[k]))
    .join(",");
  return "{" + body + "}";
}

export function sha256Hex(input) {
  return crypto.createHash("sha256").update(input).digest("hex");
}

/**
 * Create a receipt + integrity hash.
 * Hash is computed from a canonical representation of the content EXCLUDING integrity.
 */
export function createReceipt({ action, intent, evidence = [], prevHash = null }) {
  const base = {
    id: `HALO-${Date.now()}`,
    timestamp: new Date().toISOString(),
    action,
    intent,
    evidence,
    prevHash
  };

  const canonical = stableStringify(base);
  const integrity = {
    algo: "sha256",
    canonical,
    hash: sha256Hex(canonical)
  };

  return { ...base, integrity };
}

/**
 * Verify a receipt's integrity hash.
 */
export function verifyReceipt(receipt) {
  if (!receipt?.integrity?.hash || receipt?.integrity?.algo !== "sha256") return false;

  const { integrity, ...rest } = receipt;
  const canonical = stableStringify(rest);
  const hash = sha256Hex(canonical);

  return hash === integrity.hash;
}
