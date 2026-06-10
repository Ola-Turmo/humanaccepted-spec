// Package haverify implements the HumanAccepted receipt format v1.0.0
// reference verifier in Go.
//
// canonicalBytes is the byte-exact Go implementation of the canonical
// form documented in docs/canonical-form.md. It MUST be byte-equal to
// the Python reference verifier (verifier/python/verify.py) and the
// TypeScript reference verifier (verifier/typescript/verify.ts).
package haverify

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
)

// canonicalBytes returns the canonical byte form of a receipt. The signature
// signs the result of canonicalBytes on the receipt with the `signatures`
// block removed.
func canonicalBytes(v interface{}) ([]byte, error) {
	var buf bytes.Buffer
	if err := writeCanonical(&buf, v); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeCanonical(buf *bytes.Buffer, v interface{}) error {
	switch x := v.(type) {
	case nil:
		buf.WriteString("null")
	case bool:
		if x {
			buf.WriteString("true")
		} else {
			buf.WriteString("false")
		}
	case string:
		b, err := json.Marshal(x)
		if err != nil {
			return err
		}
		buf.Write(b)
	case float64:
		if !isFinite(x) {
			return fmt.Errorf("non-finite number: %v", x)
		}
		b, err := json.Marshal(x)
		if err != nil {
			return err
		}
		buf.Write(b)
	case int:
		b, err := json.Marshal(x)
		if err != nil {
			return err
		}
		buf.Write(b)
	case int64:
		b, err := json.Marshal(x)
		if err != nil {
			return err
		}
		buf.Write(b)
	case []interface{}:
		buf.WriteByte('[')
		for i, item := range x {
			if i > 0 {
				buf.WriteByte(',')
			}
			if item == nil {
				buf.WriteString("null")
			} else {
				if err := writeCanonical(buf, item); err != nil {
					return err
				}
			}
		}
		buf.WriteByte(']')
	case map[string]interface{}:
		// Keep null-valued keys (matches Python: keep null).
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sortStrings(keys)
		buf.WriteByte('{')
		for i, k := range keys {
			if i > 0 {
				buf.WriteByte(',')
			}
			kb, err := json.Marshal(k)
			if err != nil {
				return err
			}
			buf.Write(kb)
			buf.WriteByte(':')
			vv := x[k]
			if vv == nil {
				buf.WriteString("null")
			} else {
				if err := writeCanonical(buf, vv); err != nil {
					return err
				}
			}
		}
		buf.WriteByte('}')
	default:
		return fmt.Errorf("unsupported type: %T", v)
	}
	return nil
}

// sortStrings sorts a slice of strings bytewise. Go's stdlib sort.Strings
// uses a locale-aware sort; we want raw byte sort (matches Python's
// str comparison).
func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && compareBytes(s[j-1], s[j]) > 0; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}

func compareBytes(a, b string) int {
	la, lb := len(a), len(b)
	i := 0
	for ; i < la && i < lb; i++ {
		if a[i] != b[i] {
			return int(a[i]) - int(b[i])
		}
	}
	if la < lb {
		return -1
	}
	if la > lb {
		return 1
	}
	return 0
}

func isFinite(f float64) bool { return !isNaN(f) && !isInf(f) }
func isNaN(f float64) bool   { return f != f }
func isInf(f float64) bool   { return f > 1e308 || f < -1e308 }

// keep strconv import alive
var _ = strconv.Itoa
