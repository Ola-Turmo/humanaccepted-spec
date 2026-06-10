# Canonical form

> Version: v1.0.0 · part of the HumanAccepted receipt format spec.

The receipt format is bytes-sensitive. Two implementations that produce the same logical receipt but different bytes will produce different signatures. The canonical form below is byte-exact between all 5 reference implementations (Python, Go, TypeScript, Rust, Elixir), and is verified by the 4 conformance test vectors in `vectors/v1/`.

## Rules

1. **Recursively sort all object keys**, bytewise, by their UTF-8 code points, at every nesting level.
2. **Keep `null` values.** Do not coerce `null` to `[]`, `""`, or `0`. They are different in the canonical form.
3. **Drop only `undefined` (or missing) keys.** When round-tripping a value through JSON, a field that is `undefined` in the source object is *omitted* from the canonical form. A field that is `null` is kept.
4. **No whitespace.** The output is compact JSON (no indentation, no newlines between tokens).
5. **Arrays preserve `undefined → null`** per JavaScript's `JSON.stringify` semantics. In Python or Go, write `null` explicitly for any element that the source model considered absent.

## Worked example

Given the receipt object (keys shown in insertion order):

```json
{
  "id": "rcp_01HXY3K8M2Q9F4W7TA5V6BPE0N",
  "version": 1,
  "issued_at": "2026-06-09T16:30:00.000Z",
  "tenant": { "id": "tn_01HXY3K8M2Q9", "name": "Acme Corp", "domain": "my.co" },
  "human":  { "id": "u_olav", "email_hash": "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b2b2b2b2b2b2b2b2b2b2b2b" },
  "ai":     { "provider": "openai", "model": "gpt-5.5", "draft_hash": "sha256:6caa03…6778ef78", "draft_ref": "r2://…/draft-uuid.json" },
  "output": { "final_hash": "sha256:5d0775…cc63f06b", "final_ref": "r2://…/final-uuid.json" },
  "context": { "purpose": "marketing-email-draft", "ai_act_class": "limited_risk" },
  "signatures": { "tenant_ed25519": "ed25519:9b3a…", "cf_attestation": null }
}
```

The canonical form (the bytes that get signed) is the same JSON, with all keys sorted, no whitespace, and a stable field order. The signature signs the bytes *minus* the `signatures` block. See `docs/receipt-format.md` §3 for the exact algorithm.

## Implementation

The reference implementations in `verifier/python/verify.py` produce canonical bytes via the `canonical_bytes()` function. The TypeScript reference uses `@std/canonicalize` or a 30-line recursive-sorted-keys serializer. Both produce byte-identical output for the same input.

## Why this matters

The 4 Ed25519 canonical bugs in the v0.1.0 ship (caught by the smoke test) all stemmed from drift between the sign-time and verify-time canonical form. Examples: signing before a field was set, `null` vs `undefined` confusion, `null` coerced to `[]`, URI prefix mismatches. This doc is the spec that prevents those from re-appearing in alternative implementations, and the 4 vectors in `vectors/v1/` are designed to catch regressions of all 4 categories.
