# Examples

A few example receipts to test your verifier and SDK against.

## Files

- **`receipt-v0.1.0.json`** — full receipt with all fields, a real-looking tenant + human + AI metadata, and a placeholder `tenant_ed25519` signature (all zeros). The wire format is unchanged from v1.0.0 (v1.0.0 is wire-compatible with v0.1.0); the verifier will return `"tenant signature did not verify"` until you substitute a real signature; the canonicalisation pass should still pass.

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

The 5 reference verifiers all use the same CLI shape:

```bash
# Python
python3 verifier/python/verify.py examples/receipt-v0.1.0.json <public-key-hex>

# Go
go run ./verifier/go/ examples/receipt-v0.1.0.json <public-key-hex>

# TypeScript
npx tsx verifier/typescript/verify.ts examples/receipt-v0.1.0.json <public-key-hex>

# Rust
cd verifier/rust && cargo run --release -- examples/receipt-v0.1.0.json <public-key-hex>

# Elixir
elixir -pa verifier/elixir/_build -r verifier/elixir/lib/humanaccepted_verifier.ex \
  -e "IO.inspect(HumanAccepted.Verifier.verify_receipt_file(\"examples/receipt-v0.1.0.json\", \"ed25519:<public-key-hex>\"))"
```

Any of them that disagrees with the others on the same receipt has a bug.
