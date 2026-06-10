# TypeScript reference verifier

The TypeScript reference verifier for the HumanAccepted receipt format
v1.0.0. Mirrors the Python reference verifier byte-for-byte on the
canonical form, and uses TweetNaCl for the Ed25519 verify (the only
third-party dependency). No HTTP, no async, no logging — pure function
over (receipt, public_key) → verdict.

## Install

```bash
npm install
# or: pnpm install / yarn install / bun install
```

## Usage

```ts
import { verify, publicKeyFromHexOrBytes } from "./verify.ts";

const receipt = {
  // ...the receipt object...
  signatures: { tenant_ed25519: "ed25519:<hex>", cf_attestation: null },
};
const publicKey = publicKeyFromHexOrBytes("ed25519:<hex>"); // or raw 32 bytes
const verdict = verify(receipt, publicKey);
if (verdict.valid) {
  console.log("Receipt is authentic.");
} else {
  console.error(`Invalid: ${verdict.reason}`);
}
```

The verifier is **pure-functional**. It does not call out to the network,
does not log, and does not depend on any browser or Node-specific
APIs beyond `TextEncoder` and `Uint8Array` (both available in all modern
JS environments).

## Conformance

The TypeScript verifier is byte-exact-equal in verdict to the Python
reference verifier on every vector in `vectors/v1/`. Run:

```bash
npm test
```

Expected output:

```
Running conformance vectors from <repo>/vectors/v1
Keys file: <repo>/vectors/v1/keys.json (4 entries)

  ✓ 01_minimal.json: valid
  ✓ 02_unicode.json: valid
  ✓ 03_all-optional_fields.json: valid
  ✓ 04_unsigned.json: valid

  4/4 vectors pass, 0 failed.
```

If your TypeScript verifier disagrees with the Python reference on any
vector, you have a bug. Open an issue with the failing vector and the
verdict difference.

## What this verifier guarantees

- **Byte-exact canonical form** with the Python reference. The same
  receipt produces the same canonical bytes in both implementations.
- **Ed25519 signature verification** via TweetNaCl (the de-facto standard
  for Ed25519 in JS). Pure-function, no key material is exposed.
- **Field-shape conformance** (version, signature prefix, `cf_attestation`
  is `null` in v1).
- **The exact same verdict format** as the Python reference: `{ valid:
  boolean, reason: string }`. Cross-language conformance assertions can
  compare verdicts directly.

## What this verifier does NOT do

- **Key generation.** The receipt signer (not the verifier) generates
  keys. Use any standard Ed25519 key generator (e.g. `nacl.sign.keyPair()`
  for testing; a real key in a HSM or KMS for production).
- **Canonical-form introspection.** The verifier doesn't expose the
  canonical bytes it computed. If you need to inspect them (for example
  for cross-implementation conformance), use `canonicalBytes()` from
  `canonical.ts` directly.
- **Receipt format versioning beyond v1.** pre-v1.0.0 receipts (the
  pre-release) and any future v2+ are rejected at the version check.
  Add support for new versions in a new `verifyN.ts` module, not by
  forking this one.
