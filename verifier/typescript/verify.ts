// verifier/typescript/verify.ts
//
// The TypeScript reference verifier for the HumanAccepted receipt format.
// Mirrors the Python reference verifier byte-for-byte on the canonical
// form, and uses TweetNaCl for the Ed25519 verify (the only third-party
// dependency). No HTTP, no async, no logging — pure function over
// (receipt, public_key) → verdict.
//
// Usage:
//   import { verify, VerificationKey } from "./verify.ts";
//   const result = verify(receipt, publicKey); // "valid" | "invalid: <reason>"
//
// Used by the conformance test runner (test_vectors.ts) to assert the
// TypeScript implementation matches the Python reference on every vector.

import { canonicalBytes } from "./canonical.ts";
import * as nacl from "tweetnacl";

export type VerificationKey = Uint8Array; // 32 bytes, raw Ed25519 public key

export type Verdict =
  | { valid: true; reason: "valid" }
  | { valid: false; reason: string };

/** Parse a public key from a hex string (optionally prefixed with "ed25519:")
 *  or a 32-byte Uint8Array. Throws on invalid input. */
export function publicKeyFromHexOrBytes(input: string | Uint8Array): VerificationKey {
  if (input instanceof Uint8Array) {
    if (input.length !== 32) {
      throw new Error(`Ed25519 public key must be 32 bytes, got ${input.length}`);
    }
    return input;
  }
  const s = input.trim();
  const hex = s.startsWith("ed25519:") ? s.slice("ed25519:".length) : s;
  if (!/^[0-9a-fA-F]+$/.test(hex)) {
    throw new Error(`public key not valid hex: ${hex}`);
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  if (bytes.length !== 32) {
    throw new Error(`Ed25519 public key must be 32 bytes, got ${bytes.length}`);
  }
  return bytes;
}

const MAX_KEY_LENGTH = 255;
const KEY_PATTERN = /^[A-Za-z0-9._\-]+$/;

/** Verify a receipt. Returns a Verdict describing the outcome. */
export function verify(receipt: unknown, publicKey: VerificationKey): Verdict {
  if (typeof receipt !== "object" || receipt === null) {
    return { valid: false, reason: "receipt is not an object" };
  }
  const r = receipt as Record<string, unknown>;
  if (r.version !== 1) {
    return { valid: false, reason: `unsupported version: ${r.version}` };
  }
  const sigs = (r.signatures as Record<string, unknown> | undefined) ?? {};
  const sigStr = sigs.tenant_ed25519 as string | undefined;
  if (!sigStr) {
    return { valid: false, reason: "missing signatures.tenant_ed25519" };
  }
  if (typeof sigStr !== "string" || !sigStr.startsWith("ed25519:")) {
    return { valid: false, reason: `unexpected signature prefix: ${sigStr}` };
  }
  const sigHex = sigStr.slice("ed25519:".length);
  if (!/^[0-9a-fA-F]+$/.test(sigHex)) {
    return { valid: false, reason: "signature not valid hex" };
  }
  const sig = new Uint8Array(sigHex.length / 2);
  for (let i = 0; i < sig.length; i++) {
    sig[i] = parseInt(sigHex.slice(i * 2, i * 2 + 2), 16);
  }
  if (sig.length !== 64) {
    return { valid: false, reason: `Ed25519 signature must be 64 bytes, got ${sig.length}` };
  }

  // Sign over the canonical bytes of (receipt minus the signatures block).
  const body: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(r)) {
    if (k !== "signatures") body[k] = v;
  }
  let message: Uint8Array;
  try {
    message = canonicalBytes(body);
  } catch (e) {
    return { valid: false, reason: `canonicalisation failed: ${(e as Error).message}` };
  }

  // Ed25519 verify via tweetnacl. Returns false on any mismatch.
  const ok = nacl.sign.detached.verify(message, sig, publicKey);
  if (!ok) {
    return { valid: false, reason: "tenant signature did not verify" };
  }

  return { valid: true, reason: "valid" };
}

// Suppress unused warnings: these are exported for callers who want to
// pre-parse a key.
export const __exported = { MAX_KEY_LENGTH, KEY_PATTERN };
