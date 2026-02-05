#!/usr/bin/env node

function createReceipt({ action, intent }) {
  return {
    id: `HALO-${Date.now()}`,
    timestamp: new Date().toISOString(),
    action,
    intent,
    integrity: "unverified"
  };
}

// ---- run ----
const receipt = createReceipt({
  action: "INITIALIZE_PROJECT",
  intent: "Prove HALO receipts can exist as executable artifacts"
});

console.log("HALO RECEIPT");
console.log(JSON.stringify(receipt, null, 2));
