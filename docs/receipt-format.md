# Receipt Format Spec — v1

> **Status:** Stable for v1.0.0 (June 2026). The format is the public contract; the host (`HumanAccepted`) is the paid product. Anyone can implement it. **HumanAccepted does not certify AI Act compliance** — the receipt is an evidence primitive. See §6 for how the fields map to AI Act articles; the receipt is useful evidence, not a compliance pack.

## 1. What a receipt is

A receipt is a tamper-evident, content-addressed JSON object that proves a specific human approved a specific AI output at a specific moment. It has two independent Ed25519 signatures and is verifiable offline by anyone with the tenant's public key.

A receipt is **not** a workflow approval, not a model card, not a prompt log, and **not a compliance certificate**. It is a single, signed fact: *"u_olav approved this AI draft, producing this final output, at 2026-06-09T16:30:00Z, on behalf of tenant tn_..."*

**The host product (HumanAccepted) is the evidence layer.** The receipt is the cryptographic anchor. Your own policy, risk, and consent systems are responsible for the rest.

## 2. Format

```json
{
  "id": "rcp_01HXY3K8M2Q9F4W7TA5V6BPE0N",
  "version": 1,
  "issued_at": "2026-06-09T16:30:00.000Z",
  "tenant": {
    "id": "tn_01HXY3K8M2Q9",
    "name": "Acme Corp",
    "domain": "my.co"
  },
  "human": {
    "id": "u_olav",
    "email_hash": "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
    "auth_method": "cloudflare-access:sso",
    "approver_session": "sess_01HXY..."
  },
  "ai": {
    "provider": "openai",
    "model": "gpt-5.5",
    "draft_hash": "sha256:abc123...",
    "draft_ref": "r2://HumanAccepted-payloads/rcp/draft-uuid.json"
  },
  "output": {
    "final_hash": "sha256:def456...",
    "final_ref": "r2://HumanAccepted-payloads/rcp/final-uuid.json"
  },
  "context": {
    "purpose": "marketing-email-draft",
    "ai_act_class": "limited_risk",
    "user_request_hash": "sha256:...",
    "tools_used": ["gpt-5.5", "spam-check-v2"],
    "policy_version": "p_2026.06"
  },
  "signatures": {
    "tenant_ed25519": "ed25519:5fb2c8...",
    "cf_attestation": null
  }
}
```

### 2.1 Field semantics

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Receipt ID. Format: `rcp_` + 26 chars base32-Crockford. Content-addressed (derivable from `tenant_id + human_id + ai.draft_hash + output.final_hash + issued_at`) |
| `version` | number | yes | Format version. Currently `1` |
| `issued_at` | string (ISO 8601 ms) | yes | When the receipt was issued. UTC |
| `tenant.id` | string | yes | Tenant ID. `tn_` + 12 chars base32-Crockford |
| `tenant.name` | string | yes | Tenant display name. Optional in signed payload |
| `tenant.domain` | string | yes | Tenant primary domain. Optional in signed payload |
| `human.id` | string | yes | User ID within the tenant. Tenant-scoped |
| `human.email_hash` | string | optional | `sha256:hex` of the human's lowercased email. Omit if you don't store email |
| `human.auth_method` | string | optional | How the human authenticated (e.g. `cloudflare-access:sso`, `api_key`, `webauthn`) |
| `human.approver_session` | string | optional | Session ID at the moment of approval |
| `ai.provider` | string | yes | Model provider (e.g. `openai`, `anthropic`, `google`, `cohere`, `self-hosted`) |
| `ai.model` | string | yes | Model identifier (e.g. `gpt-5.5`, `claude-sonnet-4.6`, `gemini-3-pro`) |
| `ai.draft_hash` | string | yes | `sha256:hex` of the canonical UTF-8 bytes of the AI draft |
| `ai.draft_ref` | string | optional | URI where the draft payload can be retrieved (R2 path, S3 URL, etc.) |
| `output.final_hash` | string | yes | `sha256:hex` of the canonical UTF-8 bytes of the human-accepted final output |
| `output.final_ref` | string | optional | URI where the final payload can be retrieved |
| `context.purpose` | string | yes | Free-text purpose. Conventions: `marketing-email-draft`, `contract-clause`, `clinical-note`, `support-reply` |
| `context.ai_act_class` | string | optional | Tenant-supplied risk class label (e.g. EU AI Act: `limited_risk`, `high_risk`, `minimal_risk`, `unclassified`). Carried through as evidence; not validated by HumanAccepted. |
| `context.user_request_hash` | string | optional | `sha256:hex` of the original user request that produced the AI draft |
| `context.tools_used` | string[] | optional | Names of any tools / function calls the AI invoked before the final draft |
| `context.policy_version` | string | optional | Tenant's internal policy version at the time of approval |
| `signatures.tenant_ed25519` | string | yes | `ed25519:hex` of the Ed25519 signature of the canonical payload (the receipt minus this `signatures` block), signed by the tenant's private key |
| `signatures.cf_attestation` | string | optional | Reserved for future CF-issued signed envelope. Always `null` in v1 |

### 2.2 ID format

The human-readable portion of the receipt ID is **base32 Crockford** — the alphabet `0123456789ABCDEFGHJKMNPQRSTVWXYZ`. This omits the characters `I`, `L`, `O`, `U` to prevent copy-paste confusion (0 vs O, 1 vs I vs l). The 26-character suffix encodes ~130 bits of randomness, making collision probability negligible.

The full prefix is:
- `rcp_` — receipt
- `tn_` — tenant
- `key_` — API key
- `whk_` — webhook
- `sess_` — approver session

## 3. Canonical payload (what gets signed)

The signature is over the JSON of the receipt **with the `signatures` block removed**, serialized with **recursively-sorted keys and no insignificant whitespace**. `null` values are kept (not dropped); only `undefined` / missing keys are dropped. The canonical form is byte-exact between implementations.

> See **[`canonical-form.md`](./canonical-form.md)** for the standalone reference: the 5 rules, the worked example, and the byte-exact behaviour expected from any conforming implementation.

In TypeScript (the reference implementation, used by the Worker):

```typescript
function canonicalize(v: unknown): string {
  if (v === null || v === undefined) return "null";
  if (typeof v === "string" || typeof v === "number" || typeof v === "boolean")
    return JSON.stringify(v);
  if (Array.isArray(v)) {
    return "[" + v.map((x) => (x === undefined ? "null" : canonicalize(x))).join(",") + "]";
  }
  if (typeof v === "object") {
    const obj = v as Record<string, unknown>;
    const keys = Object.keys(obj).filter((k) => obj[k] !== undefined).sort();
    return "{" + keys.map((k) => JSON.stringify(k) + ":" + canonicalize(obj[k])).join(",") + "}";
  }
  return "null";
}
```

In Python:

```python
import json

def canonicalize(receipt: dict) -> bytes:
    def can(v):
        if v is None: return "null"
        if isinstance(v, bool): return "true" if v else "false"
        if isinstance(v, (int, float, str)): return json.dumps(v, separators=(",", ":"))
        if isinstance(v, list): return "[" + ",".join(can(x) for x in v) + "]"
        if isinstance(v, dict):
            return "{" + ",".join(
                json.dumps(k, separators=(",", ":")) + ":" + can(v)
                for k, v in sorted(v.items())
            ) + "}"
        return "null"
    r2 = {k: v for k, v in receipt.items() if k != "signatures"}
    return can(r2).encode("utf-8")
```

In Go:

```go
func canonicalize(v any) string {
    b, _ := json.Marshal(v)  // encoding/json sorts keys recursively
    return string(b)
}
```

**Key rules** (these are the source of the most common verification bugs):

1. **All nested object keys are sorted** (not just the top level).
2. **Null values are kept** as the literal string `null`. They are NOT dropped. The canonical form of `{"a": null}` is `{"a":null}` (7 bytes), not `{}` (2 bytes).
3. **Undefined / missing keys are dropped.** A field that was never set on the receipt object must be absent from the canonical form.
4. **No insignificant whitespace.** No spaces after `:`, `,`, etc.
5. **Arrays preserve `undefined` → `null` per JSON semantics** but typically don't contain undefined entries.

## 4. Verification (the 5 reference verifiers)

The reference verifiers live in [`verifier/`](./../verifier/), one per language. All 5 are conformant (4/4 on the test vectors in `vectors/v1/`) and produce byte-exact canonical form. The Python verifier is the canonical reference; the other 4 (Go, TypeScript, Rust, Elixir) are independently maintained to the same byte-exact standard.

| Language | Path | Crypto backend | Lines of code (approx) |
|----------|------|----------------|------------------------|
| Python | [`verifier/python/verify.py`](./../verifier/python/verify.py) | `cryptography` (`Ed25519PublicKey`) | ~60 |
| Go | [`verifier/go/main.go`](./../verifier/go/main.go) | `crypto/ed25519` (stdlib) | ~80 |
| TypeScript | [`verifier/typescript/canonical.ts`](./../verifier/typescript/canonical.ts) | `tweetnacl` | ~90 |
| Rust | [`verifier/rust/src/lib.rs`](./../verifier/rust/src/lib.rs) | `ed25519-dalek` 3.0 | ~90 |
| Elixir | [`verifier/elixir/lib/humanaccepted_verifier.ex`](./../verifier/elixir/lib/humanaccepted_verifier.ex) | Erlang `:crypto.verify/5` (stdlib) | ~80 |

The Python reference verifier (reproduced below) uses the canonicalize from §3 and the Ed25519 verify from the `cryptography` package.

```python
import json, base64
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

def canonicalize(r: dict) -> bytes:
    """Canonicalize for Ed25519 signing. Matches the Worker exactly."""
    def can(v):
        if v is None: return "null"
        if isinstance(v, bool): return "true" if v else "false"
        if isinstance(v, (int, float, str)): return json.dumps(v, separators=(",", ":"))
        if isinstance(v, list): return "[" + ",".join(can(x) for x in v) + "]"
        if isinstance(v, dict):
            return "{" + ",".join(
                json.dumps(k, separators=(",", ":")) + ":" + can(v)
                for k, v in sorted(v.items())
            ) + "}"
        return "null"
    r2 = {k: v for k, v in r.items() if k != "signatures"}
    return can(r2).encode("utf-8")

def verify_receipt(receipt: dict, tenant_public_key_b64: str) -> tuple[bool, str]:
    sig = receipt.get("signatures", {}).get("tenant_ed25519", "")
    if not sig.startswith("ed25519:"):
        return False, "tenant_ed25519 missing or malformed"
    sig_bytes = bytes.fromhex(sig[len("ed25519:"):])
    pub = Ed25519PublicKey.from_public_bytes(base64.b64decode(tenant_public_key_b64))
    payload = canonicalize(receipt)
    try:
        pub.verify(sig_bytes, payload)
        return True, "ok"
    except Exception as e:
        return False, f"signature did not verify: {e}"
```

**Usage:**

```bash
cat receipt.json | python3 verify.py "$TENANT_PUBLIC_KEY_B64"
```

## 5. Hosted verification (the public service)

If the verifier does not have the tenant's public key, the hosted service offers:

```
GET https://api.HumanAccepted/verify/{tenant_id}/{receipt_id}
→ 200 { valid: true, receipt_id, tenant_id, issued_at, ... }
→ 404 { valid: false, reason: "not_found" }
→ 200 { valid: false, reason: "tenant_key_missing" }
```

This is the **only** public endpoint that doesn't require an API key.

## 6. AI Act oversight mapping

HumanAccepted is **not a compliance platform**. It is the evidence layer. The receipt includes the fields a compliance team typically uses to document human review of AI output — use them as part of your own AI Act (or any other regulatory) workflow, alongside your policy, risk, and consent systems.

The receipt format is useful evidence for four articles of the EU AI Act. **The receipt is not itself a compliance certificate.** It is the audit-trail primitive that lets the rest of the pack be machine-verifiable.

- **Art. 12 (Logging):** the receipt is a log record with content (the AI draft hash + the final output hash + the human + the timestamp + the toolchain + the policy version).
- **Art. 14 (Human oversight):** the receipt is the proof that oversight happened — the human identity, the session, the auth method.
- **Art. 9 (Risk management):** the `context.ai_act_class` field encodes the risk class, and `context.policy_version` ties the approval to a specific version of the tenant's risk-management policy.
- **Art. 13 (Transparency):** the `context.tools_used` and `ai.model` fields document the AI system used.

> **Note:** the `context.ai_act_class` value is supplied by the tenant at the time of approval. HumanAccepted does not verify or certify it; it only carries the value forward. Your own risk-classification system is the source of truth.

## 7. Versioning

This is **v1**. Breaking changes require a new `version` integer and a new prefix (e.g. `v2_rcp_...`). Receivers should reject any receipt whose `version` is not in their supported set.

## 8. License

This spec is **CC-BY-4.0**. The reference verifier in §4 is **Apache-2.0**. The hosted service at `HumanAccepted` is a paid product; the spec itself is free to implement.
