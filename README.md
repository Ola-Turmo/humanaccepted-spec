# HumanAccepted — open spec

> **The receipt for human-in-the-loop.**
> **v1.0.0** · Apache-2.0 on code · CC-BY-4.0 on prose.

This repository contains the **open specification** for HumanAccepted: the canonical form of a human-acceptance receipt, its fields, the Ed25519 signing rules, the verifier algorithm, conformance test vectors, and 5 reference verifiers. The format is the public contract; the host product is a separate, paid service that implements it.

## The format in one paragraph

A receipt is a tamper-evident, content-addressed JSON object that proves a specific human approved a specific AI output at a specific moment. It has two independent Ed25519 signatures and is verifiable offline by anyone with the tenant's public key.

## What's in this repository

- **[`docs/receipt-format.md`](./docs/receipt-format.md)** — the v1.0.0 spec: structure, fields, canonical form, signing, verification, the AI Act oversight mapping, versioning, license.
- **[`docs/canonical-form.md`](./docs/canonical-form.md)** — the byte-exact canonicalisation rules (recursive-sorted-keys, keep `null`, drop only `undefined`).
- **[`verifier/`](./verifier/)** — 5 reference verifiers, all 4/4 conformant, all byte-exact with each other on the canonical form:
  - [`python/verify.py`](./verifier/python/verify.py) — ~60 LOC, stdlib + `cryptography`
  - [`go/`](./verifier/go) — stdlib `crypto/ed25519`, no external deps
  - [`typescript/`](./verifier/typescript) — `tweetnacl`, runs in Node 18+
  - [`rust/`](./verifier/rust) — `ed25519-dalek` 3.0, `cargo test`
  - [`elixir/`](./verifier/elixir) — Erlang/OTP's `:crypto.verify/5` (stdlib), no external deps
- **[`vectors/v1/`](./vectors/v1/)** — 4 conformance test vectors. An implementation is conformant iff it produces the same verdict on every vector as the Python reference.
- **[`.run-elixir-conformance.sh`](./.run-elixir-conformance.sh)** — one-shot script that compiles and runs the Elixir verifier's conformance test runner. Works on any host with Elixir 1.18+ and OTP 27+.
- **[`examples/`](./examples)** — a few example receipts and the canonical payloads they produce.
- **[`CHANGELOG.md`](./CHANGELOG.md)** — format change history.
- **[`CONTRIBUTING.md`](./CONTRIBUTING.md)** — how to propose a change, conformance requirements, verifier translation policy.
- **[`SECURITY.md`](./SECURITY.md)** — the security model and the in-scope / out-of-scope boundaries.

## Hosted implementation

The reference implementation is a paid product at [humanaccepted.com](https://humanaccepted.com). The source code for the hosted API is *not* in this repository; only the spec, the verifiers, and the conformance vectors are. To get a working receipt in 5 minutes, use the hosted product or one of the open-source SDKs (TS / Python, Apache-2.0).

## What HumanAccepted is not

- Not a compliance platform. The receipt is the **evidence layer** a buyer plugs into their own AI Act / SOC 2 / ISO 42001 workflow.
- Not a workflow tool. There's no "approve 50 emails in a queue" UI here.
- Not a governance dashboard. Receipts are for auditors and other machines.

## Use cases

- "I shipped AI-generated output and need to prove a human approved it." — verify offline, without trusting the API.
- "I'm a compliance officer and need to show a regulator that a specific AI output was reviewed." — the receipt is the audit-trail primitive.
- "I'm building a verifier for the AI output my agent produced." — start from the reference verifier in your language of choice (5 to pick from).
- "I want AI search engines to cite my receipts." — every `/verify/:t/:r` URL is a permanent, public, indexable reference. The `llms.txt` and `sitemap.xml` in the hosted product's `public/` directory are part of the same surface.

## Conformance

Any implementation that passes all 4 vectors in `vectors/v1/` is conformant. All 5 reference verifiers in this repository pass them with byte-exact canonical form, verified end-to-end (Python: `python3 verifier/python/test_vectors.py`, Go: `go test ./verifier/go/...`, TypeScript: `node verifier/typescript/test_vectors.cjs`, Rust: `cd verifier/rust && cargo test`, Elixir: `./.run-elixir-conformance.sh`). To propose a new vector, see `CONTRIBUTING.md`.

## License

- **Code (verifiers, examples, vectors, conformance runner):** Apache-2.0
- **Prose (spec, README):** CC-BY-4.0

See [LICENSE](./LICENSE) and the per-file headers.
