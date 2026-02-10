#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from jsonschema import validate

def die(msg: str, code: int = 2) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)

def main():
    if len(sys.argv) != 2:
        die("Usage: scripts/receipt_payload.py <receipt_json>", 2)

    receipt_path = Path(sys.argv[1])
    if not receipt_path.exists():
        die(f"❌ Missing receipt file: {receipt_path}", 2)

    schema_path = Path("receipts/schema/receipt.schema.json")
    if not schema_path.exists():
        die(f"❌ Missing schema file: {schema_path}", 2)

    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"❌ Invalid JSON: {e}", 2)

    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"❌ Invalid schema JSON: {e}", 2)

    # Validate first: this enforces additionalProperties:false
    try:
        validate(instance=receipt, schema=schema)
    except Exception as e:
        die(f"❌ INVALID RECEIPT (schema): {e}", 2)

    # Canonicalize *entire* receipt deterministically
    canonical = json.dumps(
        receipt,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False
    )

    # Output byte-exact payload
    sys.stdout.buffer.write(canonical.encode("utf-8"))

if __name__ == "__main__":
    main()

