# Contributing to the HumanAccepted spec

The HumanAccepted receipt format is a public contract. Changes to it affect every implementation.

## Compatibility

The format is at v0.1.0. Per `docs/receipt-format.md` §7 (Versioning), breaking changes require a new `version` integer and a new prefix (e.g. `v2_rcp_...`). Receivers should reject any receipt whose `version` is not in their supported set.

Backwards-compatible additions (new optional fields, new values for `context.ai_act_class`) are allowed in a minor version.

## How to propose a change

1. Open an issue with the label `spec-change`.
2. Include: the change, the motivation, the impact on existing implementations, and a worked example showing the canonical form before and after.
3. If the change is approved, a PR to this repository updates the spec doc, the CHANGELOG, and the example receipt.
4. The hosted reference implementation rolls the change on a schedule agreed with the spec maintainers.

## Canonicalisation conformance

Any new implementation MUST be byte-exact against the reference verifier in `verifier/python/verify.py` for the same input. Conformance test vectors will be added in a future minor version.

## Translations of the verifier

PRs adding the same verifier in other languages (Go, Rust, Elixir, etc.) are explicitly encouraged. They live under `verifier/<language>/` and follow the same `verify(receipt, public_key) → (ok, reason)` interface.
