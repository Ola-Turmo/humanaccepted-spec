// CJS shim to run the conformance test runner. tweetnacl is CJS-only,
// so this is the simplest path. The .ts files are the canonical source;
// this .cjs is just the CJS entry point.
const { readFileSync, readdirSync } = require("node:fs");
const { join, resolve } = require("node:path");
const nacl = require("tweetnacl");

const VECTORS_DIR = resolve(__dirname, "..", "..", "vectors", "v1");

function canonicalBytes(value) {
  return new TextEncoder().encode(toCanonicalJson(value));
}
function toCanonicalJson(value) {
  if (value === null) return "null";
  if (value === undefined) return "null";
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("non-finite");
    return JSON.stringify(value);
  }
  if (typeof value === "boolean") return value ? "true" : "false";
  if (Array.isArray(value)) return "[" + value.map((x) => toCanonicalJson(x ?? null)).join(",") + "]";
  if (typeof value === "object") {
    const keys = Object.keys(value).filter((k) => value[k] !== undefined).sort();
    return "{" + keys.map((k) => JSON.stringify(k) + ":" + toCanonicalJson(value[k])).join(",") + "}";
  }
  throw new Error("unsupported");
}

function publicKeyFromHexOrBytes(input) {
  if (input instanceof Uint8Array) {
    if (input.length !== 32) throw new Error("public key must be 32 bytes");
    return input;
  }
  const s = input.trim();
  const hex = s.startsWith("ed25519:") ? s.slice(8) : s;
  if (!/^[0-9a-fA-F]+$/.test(hex)) throw new Error("not valid hex");
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  if (bytes.length !== 32) throw new Error("public key must be 32 bytes");
  return bytes;
}

function verify(receipt, publicKey) {
  if (typeof receipt !== "object" || receipt === null) return { valid: false, reason: "not an object" };
  if (receipt.version !== 1) return { valid: false, reason: "version != 1" };
  const sigs = receipt.signatures ?? {};
  const sigStr = sigs.tenant_ed25519;
  if (!sigStr) return { valid: false, reason: "missing tenant_ed25519" };
  if (typeof sigStr !== "string" || !sigStr.startsWith("ed25519:")) return { valid: false, reason: "bad sig prefix" };
  const sigHex = sigStr.slice(8);
  if (!/^[0-9a-fA-F]+$/.test(sigHex)) return { valid: false, reason: "bad sig hex" };
  const sig = new Uint8Array(sigHex.length / 2);
  for (let i = 0; i < sig.length; i++) sig[i] = parseInt(sigHex.slice(i * 2, i * 2 + 2), 16);
  if (sig.length !== 64) return { valid: false, reason: "bad sig length" };
  const body = {};
  for (const [k, v] of Object.entries(receipt)) if (k !== "signatures") body[k] = v;
  const message = canonicalBytes(body);
  const ok = nacl.sign.detached.verify(message, sig, publicKey);
  if (!ok) return { valid: false, reason: "tenant signature did not verify" };
  return { valid: true, reason: "valid" };
}

const keys = JSON.parse(readFileSync(join(VECTORS_DIR, "keys.json"), "utf-8"));
console.log(`Running conformance vectors from ${VECTORS_DIR}`);
console.log(`Keys file: ${join(VECTORS_DIR, "keys.json")} (${Object.keys(keys).length} entries)`);
console.log();
let passed = 0, failed = 0;
const files = readdirSync(VECTORS_DIR).filter((f) => /^\d{2}_.*\.json$/.test(f)).sort();
for (const f of files) {
  const receipt = JSON.parse(readFileSync(join(VECTORS_DIR, f), "utf-8"));
  const name = receipt.name;
  const keyEntry = keys[name];
  if (!keyEntry) { console.error(`  ✗ ${f}: missing keys.json entry`); failed++; continue; }
  const pub = publicKeyFromHexOrBytes(keyEntry.public_key_hex);
  const v = verify(receipt, pub);
  if (v.valid) { passed++; console.log(`  ✓ ${f}: ${v.reason}`); }
  else { failed++; console.error(`  ✗ ${f}: ${v.reason}`); }
}
console.log();
console.log(`  ${passed}/${passed + failed} vectors pass, ${failed} failed.`);
process.exit(failed === 0 ? 0 : 1);
