# Contributing to the HumanAccepted spec

The HumanAccepted receipt format is a public contract. Changes to it affect
every implementation, so the bar is high. This document explains how to
propose a change and what to expect.

## Compatibility policy

The format is at **v1.0.0** (released 2026-06-10). Per `docs/receipt-format.md`
§7 (Versioning), breaking changes require a new `version` integer AND a new
prefix (e.g. `v2_rcp_...`). Receivers should reject any receipt whose
`version` is not in their supported set. Receivers MAY support multiple
versions concurrently.

Backwards-compatible additions are allowed in a minor version:
- New optional fields on existing objects (e.g. `human.foo`)
- New values for `context.ai_act_class` (e.g. `systemic_risk`)
- New `event_type` strings in the webhooks payload
- New signature fields (e.g. `signatures.cf_attestation` filling in)

Backwards-compatible changes do NOT bump `version`. They DO bump the spec
doc and the CHANGELOG, and they MUST include a new entry in
`docs/receipt-format.md` §3 (Field reference).

## How to propose a change

1. **Open an issue** with the `spec-change` label. Include:
   - The proposed change (1-2 sentences)
   - The motivation (why is this needed?)
   - The impact on existing implementations (does this break anyone?)
   - A worked example showing the canonical form before and after
2. **Wait for the maintainers to weigh in.** The repo is at
   `Ola-Turmo/humanaccepted-spec`. Maintainer response time is best-effort.
3. **Open a PR** with:
   - The spec doc update (`docs/receipt-format.md` and/or `docs/canonical-form.md`)
   - The CHANGELOG update
   - A new entry in `vectors/v1/` (see below)
   - The Python reference verifier updated if the change affects verification logic
   - The other 4 reference verifiers (Go, TypeScript, Rust, Elixir) updated to match
4. **After merge**, the hosted reference implementation (in the private
   product repo) will roll the change on a schedule agreed with the
   maintainers. The hosted product is a separate, paid service and is not
   required to roll the change immediately.

## Canonicalisation conformance (CRITICAL)

Any new implementation MUST be byte-exact against the reference verifier
in `verifier/python/verify.py` for the same input. Conformance test
vectors are in `vectors/v1/` (4 canonical inputs at the time of v1.0.0).
An implementation is conformant if and only if it produces the same
`ok` / `not_ok` / `error` verdict on each vector as the reference.

A new test vector is required for any new canonical-form edge case (e.g.
empty arrays, deeply nested objects, or unusual Unicode). The Python
reference verifier is updated to load and run the vectors in its test
suite. The other 4 reference verifiers (Go, TypeScript, Rust, Elixir)
are also updated to pass the new vector, so the byte-exact invariant
across all 5 implementations is preserved.

## Verifier translations

PRs adding the same verifier in other languages (Go, Rust, Elixir,
TypeScript, etc.) are explicitly encouraged. The repo currently ships
5 reference verifiers — Python (the canonical reference) + Go +
TypeScript + Rust + Elixir — and adding more is welcome. They live
under `verifier/<language>/` and follow the same
`verify(receipt, public_key) → (ok, reason)` interface (language-idiomatic:
`{:ok, ...} | {:error, ...}` in Elixir, `Ok(...) | Err(...)` in Rust,
etc.).

Each translated verifier must:
1. Pass all 4 vectors in `vectors/v1/` with the same verdicts as the
   Python reference.
2. Include a small test runner (a `*_test.py` or equivalent) that
   asserts the verdicts.
3. Include a README.md explaining how to run the test suite.
4. Be byte-exact on the canonical form. The same receipt must produce
   the same canonical bytes as the Python implementation.
5. Use the minimum-dependency crypto backend available in the
   language's standard library where possible (e.g. Go's
   `crypto/ed25519`, Erlang's `:crypto.verify/5`, Rust's `ed25519-dalek`).
   Pulling in a heavy crypto framework when a stdlib backend exists
   makes a verifier harder to reason about.

## Why conformance matters

The 4 Ed25519 canonical bugs caught at v0.1.0 (signed-before-mutation,
`null` vs `undefined` confusion, `null` coerced to `[]`, URI prefix
mismatches) all stemmed from drift between the sign-time and verify-time
canonical form. The vectors in `vectors/v1/` are designed to catch
regressions of all 4 categories. An implementation that passes the
vectors is highly likely to be byte-exact in the canonical form.

## Code style

- **Verifiers:** match the Python reference's style: minimum dependencies
  (stdlib + `cryptography` for Python, stdlib only for Go and Elixir,
  `tweetnacl` for TypeScript, `ed25519-dalek` for Rust). No HTTP, no
  async, no logging — the verifier is pure-function over
  (receipt, public_key) → verdict.
- **Spec docs:** clear, technical, no marketing language. Cross-reference
  other docs in the same directory.
- **CHANGELOG:** one entry per release. The version header is the
  release date (YYYY-MM-DD).
