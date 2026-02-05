#!/usr/bin/env node
import { createReceipt, verifyReceipt } from "./receipt.js";

// ---- demo run ----
const receipt = createReceipt({
  action: "INITIALIZE_PROJECT",
  intent: "Prove HALO receipts can exist as tamper-evident executable artifacts",
  evidence: [
    "repo: Swixixle/HALO-RECEIPTS",
    "demo: node src/index.js"
  ],
  prevHash: null
});

console.log("HALO RECEIPT (original)");
console.log(JSON.stringify(receipt, null, 2));
console.log("verified:", verifyReceipt(receipt));

// Tamper test
const tampered = structuredClone(receipt);
tampered.intent = "I changed the intent after the fact";

console.log("\nHALO RECEIPT (tampered)");
console.log(JSON.stringify(tampered, null, 2));
console.log("verified:", verifyReceipt(tampered));
