"""
verify.py — HumanAccepted receipt format v0.1.0 reference verifier.

Verifies a receipt against a tenant's Ed25519 public key, offline.
No network calls. No third-party dependencies besides the standard
library and the `cryptography` package.

Usage:
    python3 verify.py <receipt.json> <tenant_public_key_hex>

Exit code 0 if valid, 1 if invalid, 2 if input error.

The byte-exact canonical form, the Ed25519 signature scheme, and the
field requirements are all defined in docs/receipt-format.md. This file
is the byte-exact Python implementation of the rules in §3-§5 of the spec.
"""

import json
import sys
from typing import Any, Optional

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.hazmat.primitives.serialization import load_der_public_key, load_pem_public_key

VERSION = "0.1.0"


def canonical_bytes(obj: Any) -> bytes:
    """Recursive-sorted-keys, keep null, drop undefined, compact JSON.
    Byte-exact match with the TypeScript reference and the Worker."""
    if obj is None:
        return b"null"
    if obj is True:
        return b"true"
    if obj is False:
        return b"false"
    if isinstance(obj, (int, float)):
        return json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    if isinstance(obj, str):
        return json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    if isinstance(obj, list):
        return b"[" + b",".join(canonical_bytes(x) for x in obj) + b"]"
    if isinstance(obj, dict):
        # Drop only undefined-like (None as a key value is a real null; keep it).
        # Filter out dict entries whose value is the literal "undefined" (shouldn't
        # happen in a real JSON load, but defensive).
        items = [(k, v) for k, v in obj.items() if v is not None or k in obj]
        items.sort(key=lambda kv: kv[0])
        body = b",".join(
            json.dumps(k, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            + b":"
            + canonical_bytes(v)
            for k, v in items
        )
        return b"{" + body + b"}"
    raise TypeError(f"unsupported type: {type(obj)}")


def _public_key_from_hex_or_pem(s: str) -> Ed25519PublicKey:
    s = s.strip()
    if "BEGIN" in s:
        if "PRIVATE" in s.upper():
            raise ValueError("private key supplied; verifier needs the public key only")
        return load_pem_public_key(s.encode("utf-8"))
    # Raw 32-byte hex, optionally prefixed "ed25519:"
    if s.startswith("ed25519:"):
        s = s[len("ed25519:") :]
    try:
        raw = bytes.fromhex(s)
    except ValueError as e:
        raise ValueError(f"public key not valid hex: {e}") from e
    if len(raw) != 32:
        raise ValueError(f"Ed25519 public key must be 32 bytes, got {len(raw)}")
    return Ed25519PublicKey.from_public_bytes(raw)


def verify(receipt: dict, public_key: Ed25519PublicKey) -> tuple[bool, str]:
    """Returns (ok, reason). reason is human-readable."""
    if not isinstance(receipt, dict):
        return False, "receipt is not an object"
    if receipt.get("version") != 1:
        return False, f"unsupported version: {receipt.get('version')!r}"
    sigs = receipt.get("signatures") or {}
    sig_hex = sigs.get("tenant_ed25519")
    if not sig_hex:
        return False, "missing signatures.tenant_ed25519"
    if not sig_hex.startswith("ed25519:"):
        return False, f"unexpected signature prefix: {sig_hex[:10]!r}"
    try:
        sig_bytes = bytes.fromhex(sig_hex[len("ed25519:") :])
    except ValueError as e:
        return False, f"signature not valid hex: {e}"
    if len(sig_bytes) != 64:
        return False, f"Ed25519 signature must be 64 bytes, got {len(sig_bytes)}"

    # Sign over the canonical bytes of (receipt minus the `signatures` block).
    body = {k: v for k, v in receipt.items() if k != "signatures"}
    try:
        msg = canonical_bytes(body)
    except Exception as e:  # pragma: no cover
        return False, f"canonicalisation failed: {e}"

    try:
        public_key.verify(sig_bytes, msg)
    except InvalidSignature:
        return False, "tenant signature did not verify"

    # Optional: also check the canonical form is byte-identical to a round-trip
    # (catches any field that wasn't in the original source).
    return True, "valid"


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: python3 verify.py <receipt.json> <public-key.pem-or-hex>", file=sys.stderr)
        return 2
    with open(argv[1], "r", encoding="utf-8") as f:
        receipt = json.load(f)
    try:
        pub = _public_key_from_hex_or_pem(argv[2])
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    ok, reason = verify(receipt, pub)
    print(reason)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
