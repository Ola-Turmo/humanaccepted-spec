# Changelog

All notable changes to the HumanAccepted receipt format spec.

## v0.1.0 — 2026-06-09

- First public release. Format is stable for the v0.1.0 product.
- Canonical form: recursive-sorted-keys, keep `null`, drop only `undefined`. Arrays preserve `undefined → null` per `JSON.stringify` semantics.
- Two Ed25519 signatures: `tenant_ed25519` (mandatory, tenant signing key) and `cf_attestation` (reserved, always `null` in v1).
- Field `context.ai_act_class` carries an EU AI Act risk class label: `limited_risk`, `high_risk`, `minimal_risk`, `unclassified`. Tenant-supplied; not validated by the format.
- Reference verifier: Python, ~60 lines, depends only on the standard library + `cryptography`.
