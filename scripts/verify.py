#!/usr/bin/env python3
import argparse, hashlib, json, sys
from pathlib import Path

def die(msg, code=1):
    print(msg, file=sys.stderr)
    raise SystemExit(code)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("transcript_file")
    ap.add_argument("receipt_json")
    args = ap.parse_args()

    transcript = Path(args.transcript_file)
    receipt = Path(args.receipt_json)

    if not transcript.is_file():
        die(f"❌ Transcript not found: {transcript}", 2)
    if not receipt.is_file():
        die(f"❌ Receipt not found: {receipt}", 2)

    try:
        r = json.loads(receipt.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"❌ Failed to read receipt JSON: {e}", 2)

    try:
        alg = r["content_hash"]["alg"]
        expected_hash = r["content_hash"]["value"]
        expected_bytes = int(r["subject"]["byte_length"])
    except Exception as e:
        die(f"❌ Receipt missing/invalid fields: {e}", 2)

    if alg != "sha256":
        die(f"❌ Unsupported hash algorithm: {alg}", 3)

    data = transcript.read_bytes()
    actual_bytes = len(data)
    actual_hash = hashlib.sha256(data).hexdigest()

    if actual_bytes != expected_bytes:
        print("❌ BYTE LENGTH MISMATCH")
        print(f"expected: {expected_bytes}")
        print(f"actual:   {actual_bytes}")
        raise SystemExit(1)

    if actual_hash != expected_hash:
        print("❌ HASH MISMATCH")
        print(f"expected: {expected_hash}")
        print(f"actual:   {actual_hash}")
        raise SystemExit(1)

    print("✅ VERIFIED")
    print(f"hash: {actual_hash}")

if __name__ == "__main__":
    main()
