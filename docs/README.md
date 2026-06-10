# Docs

The HumanAccepted receipt format spec, in this directory.

- **[receipt-format.md](./receipt-format.md)** — the v0.1.0 spec. Read this first.
- **[canonical-form.md](./canonical-form.md)** — the byte-exact canonicalisation rules. Critical for any implementer.
- **[verifier/python/](../verifier/python/verify.py)** — the reference verifier (60 lines, `cryptography` only).
- **[CHANGELOG.md](../CHANGELOG.md)** — format change history.

The hosted implementation at [humanaccepted.com](https://humanaccepted.com) implements this spec. The source code for the hosted API is in a separate private repository; only the spec and verifier are public.

## License

- **Code (verifier, examples):** Apache-2.0
- **Prose (this spec, READMEs):** CC-BY-4.0
