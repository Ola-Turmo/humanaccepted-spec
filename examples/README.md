# Examples

A few example receipts to test your verifier and SDK against.

## Files

- **`receipt-v0.1.0.json`** — full receipt with all fields, a real-looking tenant + human + AI metadata, and a placeholder `tenant_ed25519` signature (all zeros). The verifier will return `"tenant signature did not verify"` until you substitute a real signature; the canonicalisation pass should still pass.

## Generating a valid signature for testing

```python
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

priv = Ed25519PrivateKey.generate()
pub = priv.public_key()

# ... build your receipt dict ...
sig = priv.sign(canonical_bytes({k: v for k, v in receipt.items() if k != "signatures"}))
receipt["signatures"]["tenant_ed25519"] = "ed25519:" + sig.hex()
```

## Verifying a receipt

```bash
python3 verifier/python/verify.py examples/receipt-v0.1.0.json <public-key-hex>
```
