# Conformance test vectors (v1)

These are canonical test inputs for any implementation of the HumanAccepted
receipt format spec v1.0.0. An implementation is conformant if and only if
its reference verifier produces the same `ok` / `not_ok` / `error` verdict
on each vector as the Python reference verifier in `verifier/python/verify.py`.

## File naming

- `NN_descriptive-name.json` — one vector per file
- The number prefix (`01`, `02`, ...) is the canonical ordering. Add new
  vectors to the end; never renumber.

## How to use

```python
# Python reference verifier
import json
from pathlib import Path
from verifier.python.verify import verify, _public_key_from_hex_or_pem

VECTORS = Path("vectors/v1").glob("*.json")
PUBKEY = "ed25519:" + bytes(32).hex()  # zeroed key — every signature here is PLACEHOLDER-SIG

for path in sorted(VECTORS):
    receipt = json.loads(path.read_text())
    if receipt["signatures"]["tenant_ed25519"] == "PLACEHOLDER-SIG":
        # The vector has a placeholder signature. The verifier should reject
        # the signature but the structural checks (version, field shape) should
        # pass.
        ok, reason = verify(receipt, _public_key_from_hex_or_pem(PUBKEY))
        assert ok is False, f"{path.name}: expected signature failure, got valid"
        assert reason == "tenant signature did not verify"
    else:
        # Real signed vector. Implementation should verify the signature.
        ok, reason = verify(receipt, public_key)
        assert ok is True, f"{path.name}: expected valid, got {reason}"
```

## Vector catalogue

| # | Name | Tests |
|---|---|---|
| 01 | minimal | Required fields only. The smallest valid receipt. |
| 02 | unicode | Non-ASCII (Chinese, German umlaut, emoji, Zalgo) in `tenant.name` and `context.purpose`. Confirms the canonical form is UTF-8-safe. |
| 03 | all-optional | Every optional field populated (`email_hash`, `auth_method`, `approver_session`, `user_request_hash`, `tools_used`, `policy_version`). Confirms the canonical form handles absent fields correctly. |
| 04 | signature-shape | `cf_attestation: null` (the only legal value in v1). Confirms the verifier doesn't choke on the reserved counter-signature field. |

## Adding a new vector

1. Pick a name describing what the vector tests (e.g. `05-large-payload`).
2. Use the existing v1 receipt schema. Sign the canonical bytes with a
   real Ed25519 key for the signature, OR leave `PLACEHOLDER-SIG` for
   signature-shape tests.
3. Verify it round-trips through the Python reference verifier.
4. Submit a PR. The PR description should include: what the vector tests,
   the expected verdict, and a 1-line worked example of the canonical form.

## Why the canonical form matters

The 4 Ed25519 canonical bugs in the v0.1.0 ship (caught by the smoke test)
all stemmed from drift between the sign-time and verify-time canonical
form. The vectors in this directory lock the canonical form down: any
implementation that produces different canonical bytes for the same
logical receipt will fail the signature check on at least one vector.
