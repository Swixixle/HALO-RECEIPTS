#!/usr/bin/env python3
import json, sys, hashlib, os, subprocess, tempfile
from pathlib import Path
from datetime import datetime, timezone

from jsonschema import validate

NAMESPACE = "halo-envelope"
CES_VERSION = "1.0"

def die(msg: str, code: int = 2) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)

def canonical_json_bytes(obj) -> bytes:
    s = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return s.encode("utf-8")

def now_utc_z() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def main():
    if len(sys.argv) != 3:
        die("Usage: scripts/make_halo_envelope.py <event_json> <signer_id>", 2)

    event_path = Path(sys.argv[1])
    signer_id = sys.argv[2]

    if not event_path.is_file():
        die(f"❌ Missing event file: {event_path}", 2)

    schema_path = Path("receipts/schema/receipt.schema.json")
    if not schema_path.is_file():
        die(f"❌ Missing schema file: {schema_path}", 2)

    try:
        event = json.loads(event_path.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"❌ Invalid event JSON: {e}", 2)

    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except Exception as e:
        die(f"❌ Invalid schema JSON: {e}", 2)

    # Validate event strictly
    try:
        validate(instance=event, schema=schema)
    except Exception as e:
        die(f"❌ INVALID EVENT (schema): {e}", 2)

    # Exclude extensions from hashed core (semantic drift area)
    if isinstance(event, dict) and "extensions" in event:
        event_for_hash = dict(event)
        event_for_hash.pop("extensions", None)
    else:
        event_for_hash = event

    event_bytes = canonical_json_bytes(event_for_hash)
    event_hash = hashlib.sha256(event_bytes).hexdigest()

    timestamp_utc = now_utc_z()

    # Signature payload (NO trailing newline)
    payload = (
        f"{CES_VERSION}\n"
        f"{event_hash}\n"
        f"{signer_id}\n"
        f"{timestamp_utc}"
    ).encode("utf-8")

    signing_key = Path(os.path.expanduser("~/.ssh/halo_receipts"))
    if not signing_key.is_file():
        die(f"❌ Missing signing key: {signing_key}", 2)

    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        payload_path = td / "payload.bin"
        payload_path.write_bytes(payload)

        # ssh-keygen writes payload.bin.sig
        cmd = ["ssh-keygen", "-Y", "sign", "-f", str(signing_key), "-n", NAMESPACE, str(payload_path)]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        sig_path = Path(str(payload_path) + ".sig")
        if not sig_path.is_file():
            die(f"❌ Expected signature file not produced: {sig_path}", 2)

        signature = sig_path.read_text(encoding="utf-8")
        if not signature.endswith("\n"):
            signature += "\n"

    envelope = {
        "schema": "halo_envelope_v1",
        "ces_version": CES_VERSION,
        "namespace": NAMESPACE,
        "event_hash_alg": "sha256",
        "event_hash": event_hash,
        "signer_id": signer_id,
        "timestamp_utc": timestamp_utc,
        "signature": signature,
    }

    out_path = event_path.with_suffix(event_path.suffix + ".halo.json")
    out_path.write_text(json.dumps(envelope, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"✅ WROTE {out_path}")

if __name__ == "__main__":
    main()
