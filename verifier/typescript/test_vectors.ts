// verifier/typescript/test_vectors.ts
//
// Conformance test runner for the TypeScript reference verifier.
// Loads every vector in vectors/v1/ and asserts that verify() produces
// the same verdict as the Python reference (4/4 pass).
//
// Usage:
//   cd verifier/typescript
//   npm install tweetnacl
//   tsx test_vectors.ts   # or: npx tsx test_vectors.ts
//
// Exit code: 0 on full pass, 1 on any failure. Each failure prints
// the verdict + reason to stderr.
//
// Cross-language conformance: a Go, Rust, or Elixir verifier claiming
// compliance should run the same loop and assert all 4 vectors pass
// with the same verdicts. The vectors are the spec.

import { readFileSync, readdirSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { verify, publicKeyFromHexOrBytes } from "./verify.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const VECTORS_DIR = resolve(__dirname, "..", "..", "vectors", "v1");

interface KeysFile {
  [vectorName: string]: {
    public_key_hex: string;
    algorithm: string;
  };
}

function loadKeys(): KeysFile {
  try {
    return JSON.parse(readFileSync(join(VECTORS_DIR, "keys.json"), "utf-8"));
  } catch (e) {
    console.error(`Failed to load ${VECTORS_DIR}/keys.json:`, e);
    return {};
  }
}

function iterVectors(): string[] {
  return readdirSync(VECTORS_DIR)
    .filter((f) => /^\d{2}_.*\.json$/.test(f))
    .sort();
}

function checkOne(vectorName: string, file: string, keys: KeysFile): { ok: boolean; detail: string } {
  const receipt = JSON.parse(file);
  const name = receipt.name;
  if (receipt.version !== 1) {
    return { ok: false, detail: `${name}: expected version=1, got ${receipt.version}` };
  }
  const sigs = receipt.signatures ?? {};
  const sig = sigs.tenant_ed25519;
  if (typeof sig !== "string" || !sig.startsWith("ed25519:")) {
    return { ok: false, detail: `${name}: signatures.tenant_ed25519 is not an ed25519:hex value` };
  }
  if (sigs.cf_attestation != null) {
    return { ok: false, detail: `${name}: cf_attestation must be null in v1` };
  }
  const keyEntry = keys[name];
  if (!keyEntry) {
    return { ok: false, detail: `${name}: missing entry in keys.json` };
  }
  const pub = publicKeyFromHexOrBytes(keyEntry.public_key_hex);
  const verdict = verify(receipt, pub);
  if (!verdict.valid) {
    return { ok: false, detail: `${name}: verify() returned valid=false, reason=${verdict.reason}` };
  }
  return { ok: true, detail: verdict.reason };
}

function main(): number {
  const keys = loadKeys();
  console.log(`Running conformance vectors from ${VECTORS_DIR}`);
  console.log(`Keys file: ${join(VECTORS_DIR, "keys.json")} (${Object.keys(keys).length} entries)`);
  console.log();
  let passed = 0;
  let failed = 0;
  for (const fname of iterVectors()) {
    const fpath = join(VECTORS_DIR, fname);
    const file = readFileSync(fpath, "utf-8");
    const receipt = JSON.parse(file);
    const r = checkOne(receipt.name, file, keys);
    if (r.ok) {
      passed++;
      console.log(`  ✓ ${fname}: ${r.detail}`);
    } else {
      failed++;
      console.error(`  ✗ ${fname}: ${r.detail}`);
    }
  }
  console.log();
  const total = passed + failed;
  console.log(`  ${passed}/${total} vectors pass, ${failed} failed.`);
  return failed === 0 ? 0 : 1;
}

// Export for programmatic use
export { checkOne, loadKeys, iterVectors, main };

if (import.meta.url === `file://${process.argv[1]}`) {
  process.exit(main());
}
