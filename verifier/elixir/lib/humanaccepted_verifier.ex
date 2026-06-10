defmodule HumanAccepted.Verifier do
  @moduledoc """
  Reference verifier for the HumanAccepted receipt format v1.0.0.
  Byte-exact with the Python, Go, TypeScript, and Rust reference verifiers.
  No external deps. Pure function.
  """

  # Ensure :crypto is started for :crypto.verify/5 to work.
  # (On the first call after boot, this is a no-op if already started.)
  defp ensure_crypto_started, do: Application.ensure_all_started(:crypto)


  @doc """
  Parse a public key from a hex string, optionally prefixed with "ed25519:".
  """
  @spec public_key_from_hex(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def public_key_from_hex(input) do
    hex =
      case String.trim(input) do
        "ed25519:" <> rest -> rest
        rest -> rest
      end

    cond do
      not Regex.match?(~r/^[0-9a-fA-F]+$/, hex) ->
        {:error, "public key not valid hex"}

      String.length(hex) != 64 ->
        {:error, "Ed25519 public key must be 32 bytes (64 hex chars), got #{div(String.length(hex), 2)}"}

      true ->
        case Base.decode16(hex, case: :mixed) do
          {:ok, bytes} -> {:ok, bytes}
          :error -> {:error, "public key hex decode failed"}
        end
    end
  end

  @doc """
  Verify a receipt (decoded JSON value) against a 32-byte public key.
  """
  @spec verify(any(), binary()) :: %{valid: boolean(), reason: String.t()}
  def verify(receipt, pub_key) when is_binary(pub_key) and byte_size(pub_key) == 32 do
    cond do
      not is_map(receipt) ->
        fail("receipt is not an object")

      not is_map_key(receipt, "version") ->
        fail("missing version")

      receipt["version"] != 1 ->
        fail("unsupported version: #{inspect(receipt["version"])}")

      not is_map_key(receipt, "signatures") ->
        fail("missing signatures")

      not is_map(receipt["signatures"]) ->
        fail("signatures is not an object")

      not is_map_key(receipt["signatures"], "tenant_ed25519") ->
        fail("missing signatures.tenant_ed25519")

      true ->
        do_verify(receipt, pub_key)
    end
  end

  defp do_verify(receipt, pub_key) do
    sig_str = receipt["signatures"]["tenant_ed25519"]
    sig_hex = strip_ed25519_prefix(sig_str)

    cond do
      not Regex.match?(~r/^[0-9a-fA-F]+$/, sig_hex) ->
        fail("signature not valid hex")

      String.length(sig_hex) != 128 ->
        fail("Ed25519 signature must be 64 bytes, got #{div(String.length(sig_hex), 2)}")

      is_map_key(receipt["signatures"], "cf_attestation") and
          receipt["signatures"]["cf_attestation"] != nil ->
        fail("cf_attestation must be null in v1")

      true ->
        case Base.decode16(sig_hex, case: :mixed) do
          {:ok, sig_bytes} ->
            verify_with_sig(receipt, pub_key, sig_bytes)

          :error ->
            fail("signature hex decode failed")
        end
    end
  end

  defp verify_with_sig(receipt, pub_key, sig_bytes) do
    ensure_crypto_started()
    body = canonicalize_map(Map.delete(receipt, "signatures"))

    case :crypto.verify(:eddsa, :none, body, sig_bytes, [pub_key, :ed25519]) do
      true -> %{valid: true, reason: "valid"}
      false -> fail("tenant signature did not verify")
    end
  end

  defp strip_ed25519_prefix("ed25519:" <> rest), do: rest
  defp strip_ed25519_prefix(other), do: other

  defp fail(reason), do: %{valid: false, reason: reason}

  @doc """
  Build the canonical JSON bytes for a map, per the spec.
  """
  @spec canonicalize_map(map()) :: binary()
  def canonicalize_map(map) when is_map(map) do
    pairs =
      map
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> encode_string(k) <> ":" <> canonicalize_value(v) end)
      |> Enum.join(",")

    "{" <> pairs <> "}"
  end

  defp canonicalize_value(nil), do: "null"
  defp canonicalize_value(true), do: "true"
  defp canonicalize_value(false), do: "false"
  defp canonicalize_value(v) when is_binary(v), do: encode_string(v)
  defp canonicalize_value(v) when is_integer(v), do: Integer.to_string(v)
  defp canonicalize_value(v) when is_float(v), do: Float.to_string(v)
  defp canonicalize_value(v) when is_map(v), do: canonicalize_map(v)
  defp canonicalize_value(v) when is_list(v) do
    items = v |> Enum.map(&canonicalize_value/1) |> Enum.join(",")
    "[" <> items <> "]"
  end

  # Encode a JSON string literal (with surrounding quotes), matching Python's
  # json.dumps default behaviour: escape backslash + double-quote + control
  # characters. Pass through all other bytes.
  defp encode_string(s) when is_binary(s) do
    "\"" <> do_escape(s) <> "\""
  end

  defp do_escape(""), do: ""
  defp do_escape(<<c::utf8, rest::binary>>) do
    case c do
      ?\\ -> "\\\\" <> do_escape(rest)
      ?"  -> "\\\"" <> do_escape(rest)
      ?\b -> "\\b"  <> do_escape(rest)
      ?\f -> "\\f"  <> do_escape(rest)
      ?\n -> "\\n"  <> do_escape(rest)
      ?\r -> "\\r"  <> do_escape(rest)
      ?\t -> "\\t"  <> do_escape(rest)
      x when x < 0x20 -> "\\u" <> pad4(Integer.to_string(x, 16)) <> do_escape(rest)
      _ -> <<c::utf8>> <> do_escape(rest)
    end
  end

  defp pad4(s) when byte_size(s) == 4, do: s
  defp pad4(s), do: String.duplicate("0", 4 - byte_size(s)) <> s
end
