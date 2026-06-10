use std::path::Path;
use std::fs;
use humanaccepted_verifier::{public_key_from_hex, verify};

fn main() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap().parent().unwrap();
    let vectors_dir = root.join("vectors").join("v1");
    let keys: serde_json::Value = serde_json::from_str(
        &fs::read_to_string(vectors_dir.join("keys.json")).unwrap()
    ).unwrap();
    println!("Running conformance vectors from {}", vectors_dir.display());
    println!("Keys file: {}/keys.json ({} entries)", vectors_dir.display(),
        keys.as_object().map(|o| o.len()).unwrap_or(0));
    println!();
    let mut passed = 0u32; let mut failed = 0u32;
    let mut entries: Vec<_> = fs::read_dir(&vectors_dir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some("json"))
        .collect();
    entries.sort_by_key(|e| e.file_name());
    for entry in &entries {
        let path = entry.path();
        let name = entry.file_name().to_str().unwrap().to_string();
        if name == "keys.json" { continue; }
        let receipt_val: serde_json::Value = serde_json::from_str(
            &fs::read_to_string(&path).unwrap()
        ).unwrap();
        let receipt_name = receipt_val.get("name").unwrap().as_str().unwrap();
        let ke = keys.get(receipt_name).unwrap();
        let pub_hex = ke.get("public_key_hex").unwrap().as_str().unwrap();
        let pub_key = public_key_from_hex(pub_hex).unwrap();
        let v = verify(&fs::read_to_string(&path).unwrap(), &pub_key);
        if v.valid { passed += 1; println!("  ✓ {}: {}", name, v.reason); }
        else { failed += 1; eprintln!("  ✗ {}: {}", name, v.reason); }
    }
    let total = passed + failed;
    println!("\n  {}/{} vectors pass, {} failed.", passed, total, failed);
    std::process::exit(if failed == 0 { 0 } else { 1 });
}
