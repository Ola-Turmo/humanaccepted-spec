# Conformance test vectors (v1)

These are canonical test inputs for any implementation of the HumanAccepted
receipt format spec v1.0.0. An implementation is conformant if and only if
its reference verifier produces the same `valid` / `invalid` / `error` verdict
on each vector as the Python reference verifier in `verifier/python/verify.py`.

## File naming

- `NN_descriptive-name.json` — one vector per file
- The number prefix (`01`, `02`, ...) is the canonical ordering. Add new
  vectors to the end; never renumber.
- `keys.json` — the per-vector public keys, one per vector name.

## Signing

Each vector is signed with a **deterministic per-vector Ed25519 key**
derived as `sha256("humanaccepted-conformance-v1:" + vector_name)`. The
private key is the 32-byte hash digest; the public key is the
corresponding Ed25519 public scalar. The same input always produces the
same key.

Public keys live in `keys.json`, NOT in the vector files themselves. The
rationale: embedding the public key in the receipt pollutes the canonical
form (the verifier would sign over the embedded key, making the signature
useless for testing). Keep the receipt payload as a *real* receipt
with no test-specific fields.

## How to use

```python
# Python reference verifier
import json
from pathlib import Path
from verifier.python.verify import verify, _public_key_from_hex_or_pem
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

KEYS = json.loads(Path("vectors/v1/keys.json").read_text())
VECTORS = sorted(Path("vectors/v1").glob("[0-9][0-9]_*.json"))

for path in VECTORS:
    receipt = json.loads(path.read_text())
    name = receipt["name"]
    key_hex = KEYS[name]["public_key_hex"]
    pub = Ed25519PublicKey.from_public_bytes(bytes.fromhex(key_hex))
    ok, reason = verify(receipt, pub)
    assert ok is True, f"{path.name}: {reason}"
    print(f"  ✓ {path.name}: valid")
```

A reference test runner that does this is in
`verifier/python/test_vectors.py`. It is the spec's conformance oracle —
if your verifier disagrees with it on any vector, you have a bug.

## Vector catalogue

| # | Name | Tests |
|---|---|---|
| 01 | minimal | Required fields only. The smallest valid receipt. |
| 02 | unicode | Non-ASCII (Chinese, German umlaut, emoji, Zalgo) in `tenant.name` and `context.purpose`. Confirms the canonical form is UTF-8-safe. |
| 03 | all-optional | Every optional field populated (`email_hash`, `auth_method`, `approver_session`, `user_request_hash`, `tools_used`, `policy_version`). Confirms the canonical form handles absent fields correctly. |
| 04 | signature-shape | `cf_attestation: null` (the only legal value in v1). Confirms the verifier doesn't choke on the reserved counter-signature field. |

## Adding a new vector

1. Pick a name describing what the vector tests (e.g. `05-large-payload`).
2. Use the existing v1 receipt schema. No test-specific fields.
3. Sign the canonical bytes with the deterministic per-vector key. The
   easiest way is to use the `test_vectors.py` signing helper:
   ```bash
   python3 -c "
   import hashlib, json
   from pathlib import Path
   from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
   from verifier.python.verify import canonical_bytes
   path = Path('vectors/v1/05_your_vector.json')
   receipt = json.loads(path.read_text())
   name = receipt['name']
   seed = hashlib.sha256(('humanaccepted-conformance-v1:' + name).encode()).digest()
   priv = Ed25519PrivateKey.from_private_bytes(seed)
   body = {k: v for k, v in receipt.items() if k != 'signatures'}
   sig = priv.sign(canonical_bytes(body))
   receipt['signatures']['tenant_ed25519'] = 'ed25519:' + sig.hex()
   path.write_text(json.dumps(receipt, indent=2, ensure_ascii=False))
   "
   ```
4. Add the public key to `keys.json`:
   ```bash
   python3 -c "
   import hashlib, json
   from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
   name = '05: your vector name'
   seed = hashlib.sha256(('humanaccepted-conformance-v1:' + name).encode()).digest()
   priv = Ed25519PrivateKey.from_private_bytes(seed)
   keys = json.loads(open('vectors/v1/keys.json').read())
   keys[name] = {'public_key_hex': priv.public_key().public_bytes_raw().hex(), 'algorithm': 'ed25519'}
   open('vectors/v1/keys.json', 'w').write(json.dumps(keys, indent=2))
   "
   ```
5. Verify it round-trips: `python3 verifier/python/test_vectors.py`.
6. Submit a PR. The PR description should include: what the vector tests,
   the expected verdict, and a 1-line worked example of the canonical form.

## Why the canonical form matters

The 4 Ed25519 canonical bugs in the v0.1.0 ship (caught by the smoke test)
all stemmed from drift between the sign-time and verify-time canonical
form. The vectors in this directory lock the canonical form down: any
implementation that produces different canonical bytes for the same
logical receipt will fail the signature check on at least one vector.

## Why deterministic per-vector keys

Using a deterministic seed makes the vectors *reproducible* — anyone can
re-derive the private key from the vector name and re-sign the receipt
with the same signature. This is the conformance-test analog of "the
test is the test is the test." If the vectors used a single shared
private key, the test runner would conflate "is my implementation
correct?" with "is my implementation using the same public key as the
test runner?"

The keys are derived from the vector name via sha256. The seed is
`humanaccepted-conformance-v1:<vector name>` — a public, deterministic
formula. Do not use these keys for anything other than conformance
testing.
