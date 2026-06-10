// verifier/typescript/canonical.ts
//
// The byte-exact canonical form for the HumanAccepted receipt format.
// This MUST be byte-exact against the Python reference verifier in
// verifier/python/verify.py and the Worker reference in
// src/lib/receipt.ts (canonicalizeJson).
//
// Rules (from docs/canonical-form.md):
//   1. Recursively sort all object keys, bytewise, by UTF-8 code points.
//   2. Keep null values. Do not coerce null to [] or "" or 0.
//   3. Drop only undefined / missing keys. JSON.parse already drops
//      undefined; in TS the `in` check + `value === undefined` check
//      handles the case where a key is present with an explicit
//      undefined value.
//   4. No whitespace. The output is compact JSON (no indentation,
//      no newlines between tokens).
//   5. Arrays preserve undefined → null per JavaScript's JSON.stringify
//      semantics.
//
// Usage:
//   const bytes = canonicalBytes(receiptWithoutSignatures);
//   ed.verify(sig, bytes, publicKey);

export function canonicalBytes(value: unknown): Uint8Array {
  return new TextEncoder().encode(toCanonicalJson(value));
}

function toCanonicalJson(value: unknown): string {
  if (value === null) return "null";
  if (value === undefined) return "null"; // dropped at parent level
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error(`Cannot canonicalize non-finite number: ${value}`);
    }
    return JSON.stringify(value);
  }
  if (typeof value === "boolean") return value ? "true" : "false";
  if (Array.isArray(value)) {
    return "[" + value.map((x) => toCanonicalJson(x ?? null)).join(",") + "]";
  }
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    // Drop undefined-valued keys (matches the Python rule: drop only undefined)
    // Keep null-valued keys (matches the Python rule: keep null)
    const keys = Object.keys(obj)
      .filter((k) => obj[k] !== undefined)
      .sort();
    const body = keys
      .map((k) => JSON.stringify(k) + ":" + toCanonicalJson(obj[k]))
      .join(",");
    return "{" + body + "}";
  }
  throw new Error(`Cannot canonicalize value of type ${typeof value}`);
}
