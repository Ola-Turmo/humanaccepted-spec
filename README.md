# HumanAccepted — open spec

> **The receipt for human-in-the-loop.**
> v0.1.0 · Apache-2.0 on code · CC-BY-4.0 on prose.

This repository contains the **open specification** for HumanAccepted: the canonical form of a human-acceptance receipt, its fields, the Ed25519 signing rules, the verifier algorithm, and a reference implementation. The format is the public contract; the host product is a separate, paid service that implements it.

## The format in one paragraph

A receipt is a tamper-evident, content-addressed JSON object that proves a specific human approved a specific AI output at a specific moment. It has two independent Ed25519 signatures and is verifiable offline by anyone with the tenant's public key.

## What's in this repository

- **[`docs/receipt-format.md`](./docs/receipt-format.md)** — the v0.1.0 spec: structure, fields, canonical form, signing, verification, the AI Act oversight mapping, versioning, license.
- **[`docs/canonical-form.md`](./docs/canonical-form.md)** — the byte-exact canonicalisation rules (recursive-sorted-keys, keep `null`, drop only `undefined`).
- **[`verifier/python/verify.py`](./verifier/python/verify.py)** — a 60-line Python reference verifier. No dependencies beyond the standard library + `cryptography`.
- **[`examples/`](./examples)** — a few example receipts and the canonical payloads they produce.
- **[`CHANGELOG.md`](./CHANGELOG.md)** — format change history.

## Hosted implementation

The reference implementation is a paid product at [humanaccepted.com](https://humanaccepted.com). The source code for the hosted API is *not* in this repository; only the spec and verifier are. To get a working receipt in 5 minutes, use the hosted product or one of the open-source SDKs (TS / Python, Apache-2.0).

## What HumanAccepted is not

- Not a compliance platform. The receipt is the **evidence layer** a buyer plugs into their own AI Act / SOC 2 / ISO 42001 workflow.
- Not a workflow tool. There's no "approve 50 emails in a queue" UI here.
- Not a governance dashboard. Receipts are for auditors and other machines.

## Use cases

- "I shipped AI-generated output and need to prove a human approved it." — verify offline, without trusting the API.
- "I'm a compliance officer and need to show a regulator that a specific AI output was reviewed." — the receipt is the audit-trail primitive.
- "I'm building a verifier for the AI output my agent produced." — start from the reference verifier in your language of choice.

## Contributing

Issues, PRs, and discussion of the spec are welcome. Forks of the spec, alternative implementations, and verifier translations are explicitly encouraged.

## License

- **Code (verifier, examples):** Apache-2.0
- **Prose (spec, README):** CC-BY-4.0

See [LICENSE](./LICENSE) and the per-file headers.
