use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use hex::FromHex;

#[derive(Debug, Clone, PartialEq)]
pub struct Verdict {
    pub valid: bool,
    pub reason: String,
}

impl Verdict {
    pub fn ok() -> Self { Verdict { valid: true, reason: "valid".into() } }
    pub fn fail(reason: impl Into<String>) -> Self { Verdict { valid: false, reason: reason.into() } }
}

pub fn public_key_from_hex(input: &str) -> Result<VerifyingKey, String> {
    let s = input.trim();
    let hex_str = s.strip_prefix("ed25519:").unwrap_or(s);
    if !hex_str.chars().all(|c| c.is_ascii_hexdigit()) {
        return Err("public key not valid hex".into());
    }
    let bytes = Vec::<u8>::from_hex(hex_str).map_err(|e| format!("hex decode: {}", e))?;
    if bytes.len() != 32 {
        return Err(format!("Ed25519 public key must be 32 bytes, got {}", bytes.len()));
    }
    let arr: [u8; 32] = bytes.try_into().map_err(|_| "expected 32 bytes".to_string())?;
    VerifyingKey::from_bytes(&arr).map_err(|e| format!("invalid public key: {}", e))
}

pub fn verify(receipt_json: &str, pub_key: &VerifyingKey) -> Verdict {
    let receipt: serde_json::Value = match serde_json::from_str(receipt_json) {
        Ok(v) => v, Err(e) => return Verdict::fail(format!("invalid JSON: {}", e)),
    };
    let obj = match receipt.as_object() {
        Some(o) => o, None => return Verdict::fail("receipt is not an object"),
    };
    match obj.get("version").and_then(|v| v.as_i64()) {
        Some(1) => {}
        Some(v) => return Verdict::fail(format!("unsupported version: {}", v)),
        None => return Verdict::fail("missing version"),
    };
    let sigs = match obj.get("signatures").and_then(|s| s.as_object()) {
        Some(s) => s, None => return Verdict::fail("missing signatures"),
    };
    let sig_str = match sigs.get("tenant_ed25519").and_then(|s| s.as_str()) {
        Some(s) => s, None => return Verdict::fail("missing signatures.tenant_ed25519"),
    };
    let sig_hex = sig_str.strip_prefix("ed25519:").unwrap_or(sig_str);
    if !sig_hex.chars().all(|c| c.is_ascii_hexdigit()) {
        return Verdict::fail("signature not valid hex");
    }
    let sig_bytes = Vec::<u8>::from_hex(sig_hex).map_err(|e| format!("hex decode: {}", e)).unwrap();
    if sig_bytes.len() != 64 {
        return Verdict::fail(format!("Ed25519 signature must be 64 bytes, got {}", sig_bytes.len()));
    }
    let sig = match Signature::from_slice(&sig_bytes) {
        Ok(s) => s,
        Err(e) => return Verdict::fail(format!("bad signature: {}", e)),
    };
    if let Some(cf) = sigs.get("cf_attestation") {
        if !cf.is_null() { return Verdict::fail("cf_attestation must be null in v1"); }
    }
    let body = obj_without(obj, "signatures");
    let body_val = serde_json::to_value(body).unwrap();
    let canonical = canonicalize(&body_val);
    let msg = canonical.as_bytes();
    match pub_key.verify(msg, &sig) {
        Ok(()) => Verdict::ok(),
        Err(e) => Verdict::fail(format!("tenant signature did not verify: {}", e)),
    }
}

fn obj_without(obj: &serde_json::Map<String, serde_json::Value>, key: &str) -> serde_json::Map<String, serde_json::Value> {
    let mut out = serde_json::Map::new();
    for (k, v) in obj.iter() {
        if k != key { out.insert(k.clone(), v.clone()); }
    }
    out
}

fn canonicalize(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::Null => "null".to_string(),
        serde_json::Value::Bool(b) => b.to_string(),
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::String(_) => {
            serde_json::to_string(value).unwrap()
        }
        serde_json::Value::Array(arr) => {
            let items: Vec<String> = arr.iter().map(canonicalize).collect();
            format!("[{}]", items.join(","))
        }
        serde_json::Value::Object(obj) => {
            let mut keys: Vec<&String> = obj.keys().collect();
            keys.sort();
            let pairs: Vec<String> = keys.iter().map(|k| {
                format!("{}:{}", serde_json::to_string(k).unwrap(), canonicalize(&obj[*k]))
            }).collect();
            format!("{{{}}}", pairs.join(","))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::Path;

    #[test]
    fn conformance_vectors() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent().unwrap().parent().unwrap();
        let vectors_dir = root.join("vectors").join("v1");
        let keys: serde_json::Value = serde_json::from_str(
            &fs::read_to_string(vectors_dir.join("keys.json")).unwrap()
        ).unwrap();
        let mut passed = 0u32; let mut failed = 0u32;
        for entry in fs::read_dir(&vectors_dir).unwrap() {
            let entry = entry.unwrap(); let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("json") { continue; }
            let name = entry.file_name().to_str().unwrap().to_string();
            if name == "keys.json" { continue; }
            let receipt_val: serde_json::Value = serde_json::from_str(
                &fs::read_to_string(&path).unwrap()
            ).unwrap();
            let receipt_name = receipt_val.get("name").unwrap().as_str().unwrap();
            let ke = keys.get(receipt_name).unwrap();
            let pub_hex = ke.get("public_key_hex").unwrap().as_str().unwrap();
            let pub_key = public_key_from_hex(pub_hex).unwrap();
            let receipt_json = fs::read_to_string(&path).unwrap();
            let v = verify(&receipt_json, &pub_key);
            if v.valid { passed += 1; println!("  ✓ {}: {}", name, v.reason); }
            else { failed += 1; eprintln!("  ✗ {}: {}", name, v.reason); }
        }
        let total = passed + failed;
        println!("\n  {}/{} vectors pass, {} failed.", passed, total, failed);
        assert_eq!(failed, 0, "{} vectors failed", failed);
    }
}
