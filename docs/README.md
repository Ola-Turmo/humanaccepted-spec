# Docs

The HumanAccepted receipt format spec, in this directory.

- **[receipt-format.md](./receipt-format.md)** — the v1.0.0 spec. Read this first.
- **[canonical-form.md](./canonical-form.md)** — the byte-exact canonicalisation rules. Critical for any implementer.
- **[verifier/](../verifier/)** — 5 reference verifiers (Python, Go, TypeScript, Rust, Elixir), all 4/4 conformant, all byte-exact with each other.
- **[CHANGELOG.md](../CHANGELOG.md)** — format change history.

The hosted implementation at [humanaccepted.com](https://humanaccepted.com) implements this spec. The source code for the hosted API is in a separate private repository; only the spec and verifier are public.

## License

- **Code (verifier, examples):** Apache-2.0
- **Prose (this spec, READMEs):** CC-BY-4.0
