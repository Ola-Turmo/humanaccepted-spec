// main.go — conformance test runner for the Go reference verifier.
//
// Loads every vector in vectors/v1/ and asserts that Verify() produces
// the same verdict as the Python reference (4/4 pass). Run:
//
//   cd verifier/go
//   go run .
//
// Exit code: 0 on full pass, 1 on any failure. Each failure prints
// the verdict + reason to stderr.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	haverify "github.com/Ola-Turmo/humanaccepted-spec/verifier/go/haverify"
)

type keysFile map[string]struct {
	PublicKeyHex string `json:"public_key_hex"`
	Algorithm    string `json:"algorithm"`
}

func main() {
	repoRoot, err := findRepoRoot()
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not locate repo root: %v\n", err)
		os.Exit(2)
	}
	vectorsDir := filepath.Join(repoRoot, "vectors", "v1")
	keysFile := filepath.Join(vectorsDir, "keys.json")

	keys, err := loadKeys(keysFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not load %s: %v\n", keysFile, err)
		os.Exit(2)
	}

	fmt.Printf("Running conformance vectors from %s\n", vectorsDir)
	fmt.Printf("Keys file: %s (%d entries)\n", keysFile, len(keys))
	fmt.Println()

	vectors, err := listVectors(vectorsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not list vectors: %v\n", err)
		os.Exit(2)
	}

	passed, failed := 0, 0
	for _, fname := range vectors {
		receipt, err := loadReceipt(filepath.Join(vectorsDir, fname))
		if err != nil {
			fmt.Fprintf(os.Stderr, "  ✗ %s: %v\n", fname, err)
			failed++
			continue
		}
		name, _ := receipt["name"].(string)
		if v, _ := receipt["version"].(float64); v != 1 {
			fmt.Fprintf(os.Stderr, "  ✗ %s: expected version=1, got %v\n", fname, receipt["version"])
			failed++
			continue
		}
		sigs, _ := receipt["signatures"].(map[string]interface{})
		if sigs == nil {
			fmt.Fprintf(os.Stderr, "  ✗ %s: missing signatures\n", fname)
			failed++
			continue
		}
		if sigs["cf_attestation"] != nil {
			fmt.Fprintf(os.Stderr, "  ✗ %s: cf_attestation must be null in v1\n", fname)
			failed++
			continue
		}
		keyEntry, ok := keys[name]
		if !ok {
			fmt.Fprintf(os.Stderr, "  ✗ %s: missing keys.json entry for %q\n", fname, name)
			failed++
			continue
		}
		pub, err := haverify.PublicKeyFromHexOrBytes(keyEntry.PublicKeyHex)
		if err != nil {
			fmt.Fprintf(os.Stderr, "  ✗ %s: parse public key: %v\n", fname, err)
			failed++
			continue
		}
		v := haverify.Verify(receipt, pub)
		if v.Valid {
			passed++
			fmt.Printf("  ✓ %s: %s\n", fname, v.Reason)
		} else {
			failed++
			fmt.Fprintf(os.Stderr, "  ✗ %s: %s\n", fname, v.Reason)
		}
	}

	fmt.Println()
	fmt.Printf("  %d/%d vectors pass, %d failed.\n", passed, passed+failed, failed)
	if failed > 0 {
		os.Exit(1)
	}
}

func findRepoRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	dir := cwd
	for i := 0; i < 6; i++ {
		if _, err := os.Stat(filepath.Join(dir, "vectors", "v1")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", fmt.Errorf("vectors/v1 not found in any parent of %s", cwd)
}

func loadKeys(path string) (keysFile, error) {
	var k keysFile
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if err := json.NewDecoder(f).Decode(&k); err != nil {
		return nil, err
	}
	return k, nil
}

func listVectors(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []string
	for _, e := range entries {
		name := e.Name()
		if len(name) >= 5 && name[len(name)-5:] == ".json" && name != "keys.json" {
			out = append(out, name)
		}
	}
	return out, nil
}

func loadReceipt(path string) (map[string]interface{}, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var r map[string]interface{}
	if err := json.NewDecoder(f).Decode(&r); err != nil {
		return nil, err
	}
	return r, nil
}
