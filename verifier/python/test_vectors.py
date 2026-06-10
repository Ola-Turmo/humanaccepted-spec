"""
test_vectors.py — conformance test runner for the HumanAccepted receipt format.

Asserts that the Python reference verifier passes every vector in
vectors/v1/. The test runner is part of the spec so a translator
verifier (Go, Rust, etc.) can use the same vectors to assert its
own conformance.

Usage:
    python3 verifier/python/test_vectors.py
    # or:
    from verifier.python.test_vectors import run_all_vectors
    passed, failed = run_all_vectors()
    assert failed == 0, f"{failed} vectors failed"

Exit code: 0 if all vectors pass, 1 otherwise. Each failed vector
prints the verdict and reason to stderr.
"""

import json
import sys
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

# The reference verifier is in the same directory. We import via
# package-relative path so the test runner works both as `python3
# test_vectors.py` (from this dir) and as `python3 -m
# verifier.python.test_vectors` (from the repo root).
HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from verify import verify, _public_key_from_hex_or_pem  # type: ignore  # noqa: E402


# Vectors live at <repo>/vectors/v1/*.json. Resolve from this file.
REPO_ROOT = HERE.parent.parent
VECTORS_DIR = REPO_ROOT / "vectors" / "v1"
KEYS_FILE = VECTORS_DIR / "keys.json"


def _load_keys() -> dict:
    if not KEYS_FILE.exists():
        return {}
    return json.loads(KEYS_FILE.read_text(encoding="utf-8"))


def _iter_vectors():
    for path in sorted(VECTORS_DIR.glob("*.json")):
        if path.name == "keys.json":
            continue
        yield path


def _check_one(vector_path: Path, keys: dict) -> tuple[bool, str]:
    receipt = json.loads(vector_path.read_text(encoding="utf-8"))
    name = receipt.get("name", vector_path.name)

    # Structural pre-checks: version, signature shape, etc.
    if receipt.get("version") != 1:
        return False, f"{name}: expected version=1, got {receipt.get('version')!r}"
    sigs = receipt.get("signatures") or {}
    sig = sigs.get("tenant_ed25519")
    if not sig or not sig.startswith("ed25519:"):
        return False, f"{name}: signatures.tenant_ed25519 is not an ed25519:hex value"
    if "cf_attestation" in sigs and sigs["cf_attestation"] is not None:
        return False, f"{name}: cf_attestation must be null in v1"

    # The expected public key for this vector is in keys.json (we sign
    # with a deterministic per-vector key). If keys.json doesn't have an
    # entry, this vector is unsigned (e.g. a structural-only test).
    key_entry = keys.get(name)
    if not key_entry:
        # The vector has a placeholder sig. We only assert that the
        # verifier rejects it.
        # Use a dummy key to drive the verifier (the signature check
        # will fail because the placeholder isn't a real signature).
        dummy_key = _public_key_from_hex_or_pem("00" * 32)
        ok, reason = verify(receipt, dummy_key)
        if ok is True:
            return False, f"{name}: expected structural-only rejection, got valid"
        return True, f"rejected as expected (no keys.json entry): {reason}"

    # Full signature verification.
    pub = _public_key_from_hex_or_pem("ed25519:" + key_entry["public_key_hex"])
    ok, reason = verify(receipt, pub)
    if ok is not True:
        return False, f"{name}: verify() returned ok=False, reason={reason!r}"
    return True, reason


def run_all_vectors(verbose: bool = True) -> tuple[int, int]:
    """Run every vector in vectors/v1/. Returns (passed, failed)."""
    keys = _load_keys()
    passed = 0
    failed = 0
    for path in _iter_vectors():
        ok, detail = _check_one(path, keys)
        if ok:
            passed += 1
            if verbose:
                print(f"  ✓ {path.name}: {detail}")
        else:
            failed += 1
            if verbose:
                print(f"  ✗ {path.name}: {detail}", file=sys.stderr)
            else:
                print(f"  ✗ {path.name}", file=sys.stderr)
    return passed, failed


def main() -> int:
    print(f"Running conformance vectors from {VECTORS_DIR}...")
    print(f"Keys file: {KEYS_FILE} ({'present' if KEYS_FILE.exists() else 'MISSING'})")
    print()
    passed, failed = run_all_vectors()
    total = passed + failed
    print()
    print(f"  {passed}/{total} vectors pass, {failed} failed.")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
