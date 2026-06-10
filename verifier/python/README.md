# Python reference verifier

A ~60-line Python reference verifier for the HumanAccepted receipt format v1.0.0. This is the canonical reference; the other 4 reference verifiers (Go, TypeScript, Rust, Elixir) in the `verifier/` directory are independently maintained to the same byte-exact standard on the canonical form.

## Install

```bash
pip install cryptography
```

## Usage

```python
import json
from verify import verify, _public_key_from_hex_or_pem

with open("receipt.json") as f:
    receipt = json.load(f)

pub = _public_key_from_hex_or_pem(open("tenant-pub.hex").read().strip())
ok, reason = verify(receipt, pub)
print(reason)  # "valid" or "tenant signature did not verify" or other reason
```

Or from the command line:

```bash
python3 verify.py receipt.json tenant-pub.hex
# prints "valid" and exits 0, or prints the failure reason and exits 1
```

## What it verifies

1. The receipt is a JSON object with `version === 1`.
2. The receipt has a `signatures.tenant_ed25519` signature in `ed25519:hex` form (64 bytes).
3. The canonical bytes of the receipt (minus the `signatures` block) match the bytes that the signature was computed over.
4. The Ed25519 signature over those bytes is valid against the supplied public key.

## What it does *not* verify

- The `context.ai_act_class` value (it's tenant-supplied; the spec doesn't define how to validate it).
- The `issued_at` timestamp is reasonable (the spec has no time-validity rules).
- The `draft_ref` / `final_ref` URIs resolve (the verifier is offline).
- The receipt is fresh / not replayed (that's a hosted-API concern; this is offline).

The verifier is intentionally small so that any other verifier implementation can be byte-exact-validated against it.
