# Security

The HumanAccepted receipt format is built on standard Ed25519 signatures and content-addressed JSON. The security model is:

1. **Tenant's Ed25519 keypair.** The tenant generates a keypair, keeps the private key in an envelope (D1, KV, HSM, etc.), publishes the public key. Anyone with the public key can verify a receipt was signed by the tenant.
2. **Canonical form is the signed bytes.** The verifier reproduces the canonical form byte-for-byte and checks the signature against the public key.
3. **Two independent signatures in v1.** `tenant_ed25519` is mandatory (the tenant signs). `cf_attestation` is reserved for v2 (a CF-issued counter-signature, currently always `null`).
4. **Content-addressed fields.** The receipt's `ai.draft_hash` and `output.final_hash` are SHA-256 of the canonical UTF-8 bytes of the AI draft and final output. The hashes bind the receipt to specific content, so the receipt cannot be re-targeted at different text.
5. **No replay protection in the format itself.** Replay protection is a hosted-API concern (the `verify` endpoint should reject receipts whose `issued_at` is in the future or otherwise suspicious). The format has no time-validity field in v1.

## Reporting issues

Open a [GitHub issue](https://github.com/Ola-Turmo/humanaccepted-spec/issues) with the label `security`. For privately-disclosed vulnerabilities that should not be public yet, use GitHub's private vulnerability reporting on this repository.

## Out of scope for this repo

The hosted API's rate-limiting, tenant key envelope, replay protection, and abuse detection live in the private hosted-implementation repo. The format and verifier in this repo are intentionally minimal so the security model can be audited.
