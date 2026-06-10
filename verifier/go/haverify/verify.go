// Package haverify implements the HumanAccepted receipt format v1.0.0
// reference verifier in Go.
package haverify

import (
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
	"strings"
)

// Verdict is the result of verifying a receipt. Conforms to the Python
// reference verifier's { valid: bool, reason: string } shape.
type Verdict struct {
	Valid  bool
	Reason string
}

// String renders the verdict for printing.
func (v Verdict) String() string {
	if v.Valid {
		return "valid"
	}
	return "invalid: " + v.Reason
}

// PublicKey is a raw 32-byte Ed25519 public key.
type PublicKey = ed25519.PublicKey

// PublicKeyFromHexOrBytes parses a 32-byte Ed25519 public key from a hex
// string (optionally prefixed with "ed25519:") or a raw byte slice.
func PublicKeyFromHexOrBytes(input interface{}) (PublicKey, error) {
	var hexStr string
	switch x := input.(type) {
	case string:
		hexStr = x
	case []byte:
		if len(x) != ed25519.PublicKeySize {
			return nil, fmt.Errorf("public key must be %d bytes, got %d", ed25519.PublicKeySize, len(x))
		}
		return PublicKey(x), nil
	default:
		return nil, fmt.Errorf("public key must be string or []byte, got %T", input)
	}
	hexStr = strings.TrimSpace(hexStr)
	if strings.HasPrefix(hexStr, "ed25519:") {
		hexStr = hexStr[len("ed25519:"):]
	}
	if !isValidHex(hexStr) {
		return nil, fmt.Errorf("public key not valid hex")
	}
	if len(hexStr) != ed25519.PublicKeySize*2 {
		return nil, fmt.Errorf("public key must be %d hex chars, got %d", ed25519.PublicKeySize*2, len(hexStr))
	}
	b, err := hex.DecodeString(hexStr)
	if err != nil {
		return nil, fmt.Errorf("public key hex decode: %v", err)
	}
	return PublicKey(b), nil
}

func isValidHex(s string) bool {
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

// Verify checks that the receipt is well-formed and that the Ed25519
// signature in signatures.tenant_ed25519 is valid over the canonical
// bytes of the receipt with the signatures block removed.
func Verify(receipt map[string]interface{}, pub PublicKey) Verdict {
	if receipt == nil {
		return Verdict{Valid: false, Reason: "receipt is nil"}
	}
	if v, ok := receipt["version"]; !ok {
		return Verdict{Valid: false, Reason: "missing version"}
	} else if vi, ok := v.(float64); !ok {
		return Verdict{Valid: false, Reason: "version is not a number"}
	} else if vi != 1 {
		return Verdict{Valid: false, Reason: fmt.Sprintf("unsupported version: %v", v)}
	}
	sigs, _ := receipt["signatures"].(map[string]interface{})
	if sigs == nil {
		return Verdict{Valid: false, Reason: "missing signatures"}
	}
	sigStr, ok := sigs["tenant_ed25519"].(string)
	if !ok || sigStr == "" {
		return Verdict{Valid: false, Reason: "missing signatures.tenant_ed25519"}
	}
	if !strings.HasPrefix(sigStr, "ed25519:") {
		return Verdict{Valid: false, Reason: fmt.Sprintf("unexpected signature prefix: %s", truncate(sigStr, 10))}
	}
	sigHex := sigStr[len("ed25519:"):]
	sig, err := hex.DecodeString(sigHex)
	if err != nil {
		return Verdict{Valid: false, Reason: "signature not valid hex"}
	}
	if len(sig) != ed25519.SignatureSize {
		return Verdict{Valid: false, Reason: fmt.Sprintf("signature must be %d bytes, got %d", ed25519.SignatureSize, len(sig))}
	}
	body := make(map[string]interface{}, len(receipt))
	for k, v := range receipt {
		if k == "signatures" {
			continue
		}
		body[k] = v
	}
	msg, err := canonicalBytes(body)
	if err != nil {
		return Verdict{Valid: false, Reason: "canonicalisation failed: " + err.Error()}
	}
	if !ed25519.Verify(pub, msg, sig) {
		return Verdict{Valid: false, Reason: "tenant signature did not verify"}
	}
	return Verdict{Valid: true, Reason: "valid"}
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
