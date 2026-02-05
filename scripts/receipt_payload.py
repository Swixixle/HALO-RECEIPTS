#!/usr/bin/env python3
import json, sys
from pathlib import Path

p = Path(sys.argv[1])
r = json.loads(p.read_text(encoding="utf-8"))

payload = {
  "schema_version": r.get("schema_version"),
  "created_at": r.get("created_at"),
  "content_hash": {
    "alg": r["content_hash"]["alg"],
    "value": r["content_hash"]["value"],
  },
  "subject": {
    "byte_length": int(r["subject"]["byte_length"]),
    "content_type": r["subject"].get("content_type"),
    "type": r["subject"].get("type"),
  },
  "issuer": {
    "name": r.get("issuer", {}).get("name"),
    "key_id": r.get("issuer", {}).get("key_id"),
  },
}

print(json.dumps(payload, sort_keys=True, separators=(",", ":")))
