# Changelog

All notable changes to the HumanAccepted receipt format spec.

## v1.0.0 — 2026-06-10

The format is stable. Recommended for new implementations. Contains everything from v0.1.0 plus:

- **Conformance test vectors** in `vectors/v1/`. Four canonical inputs (minimal, unicode, all-optional, signature-shape) that any conformant implementation must pass.
- **CONTRIBUTING.md** is now comprehensive: compatibility policy, change proposal flow, canonicalisation conformance rule, verifier translation policy.
- **docs/canonical-form.md** is now linked from the receipt-format spec, with worked examples and an explicit "why this matters" section referencing the 4 Ed25519 canonical bugs caught at v0.1.0.
- **docs/receipt-format.md** §3 now cross-references `canonical-form.md` for the byte-exact rules.
- **Receipt ID format** is unchanged: `rcp_` + 26 base32 Crockford chars (no I, L, O, U).

Backwards-compatibility: v1.0.0 is wire-compatible with v0.1.0. Existing v0.1.0 receipts and verifiers work unchanged.

## v0.1.0 — 2026-06-09

- First public release. Format is stable for the v0.1.0 product.
- Canonical form: recursive-sorted-keys, keep `null`, drop only `undefined`. Arrays preserve `undefined → null` per `JSON.stringify` semantics.
- Two Ed25519 signatures: `tenant_ed25519` (mandatory, tenant signing key) and `cf_attestation` (reserved, always `null` in v1).
- Field `context.ai_act_class` carries an EU AI Act risk class label: `limited_risk`, `high_risk`, `minimal_risk`, `unclassified`. Tenant-supplied; not validated by the format.
- Reference verifier: Python, ~60 lines, depends only on the standard library + `cryptography`.
