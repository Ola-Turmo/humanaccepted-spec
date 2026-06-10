defmodule HumanAccepted.Verifier do
  @moduledoc """
  Reference verifier for the HumanAccepted receipt format v1.0.0.

  Byte-exact with the Python, Go, TypeScript, and Rust reference verifiers.
  Pure function over `(receipt_json, public_key_bytes) -> verdict`. No HTTP,
  no logging, no global state.

  ## Usage

      {:ok, pub} = HumanAccepted.Verifier.public_key_from_hex("ed25519:abcdef...")
      {:ok, receipt} = Jason.decode(json_string)
      verdict = HumanAccepted.Verifier.verify(receipt, pub)
      case verdict do
        %{valid: true, reason: "valid"} -> :ok
        %{valid: false, reason: reason} -> {:invalid, reason}
      end

  ## Conformance

  See `test/conformance_test.exs`. Run with `mix test` from this directory.
  Expected: 4/4 pass.
  """

  @doc """
  Parse a public key from a hex string, optionally prefixed with "ed25519:".
  Returns a 32-byte binary.
  """
  @spec public_key_from_hex(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def public_key_from_hex(input) do
    hex =
      case String.trim(input) do
        "ed25519:" <> rest -> rest
        rest -> rest
      end

    cond do
      String.length(hex) != 64 ->
        {:error, "Ed25519 public key must be 32 bytes (64 hex chars), got #{String.length(hex) / 2}"}

      not Regex.match?(~r/^[0-9a-fA-F]+$/, hex) ->
        {:error, "public key not valid hex"}

      true ->
        try do
          {:ok, Base.decode16!(hex, case: :lower)}
        rescue
          _ -> {:error, "public key hex decode failed"}
        end
    end
  end

  @doc """
  Verify a receipt (decoded JSON map) against a 32-byte public key.
  Returns a verdict map: `%{valid: true, reason: "valid"}` or `%{valid: false, reason: <string>}`.
  """
  @spec verify(map(), binary()) :: %{valid: boolean(), reason: String.t()}
  def verify(receipt, pub_key) when is_map(receipt) and is_binary(pub_key) and byte_size(pub_key) == 32 do
    cond do
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
        fail("Ed25519 signature must be 64 bytes, got #{String.length(sig_hex) / 2}")

      not is_nil(receipt["signatures"]["cf_attestation"]) and
          receipt["signatures"]["cf_attestation"] != nil ->
        fail("cf_attestation must be null in v1")

      true ->
        case Base.decode16(sig_hex, case: :lower) do
          {:ok, sig_bytes} ->
            verify_with_sig(receipt, pub_key, sig_bytes)

          :error ->
            fail("signature hex decode failed")
        end
    end
  end

  defp verify_with_sig(receipt, pub_key, sig_bytes) do
    # Build the body (receipt minus the signatures block)
    body =
      receipt
      |> Map.delete("signatures")
      |> canonicalize_map()

    # Verify with Erlang's :crypto
    case :crypto.verify(:eddsa, :none, body, sig_bytes, [pub_key, :ed25519]) do
      true -> %{valid: true, reason: "valid"}
      false -> fail("tenant signature did not verify")
    end
  end

  defp strip_ed25519_prefix("ed25519:" <> rest), do: rest
  defp strip_ed25519_prefix(other), do: other

  defp fail(reason), do: %{valid: false, reason: reason}

  @doc """
  Build the canonical bytes (JSON) for a map, per the spec.

  Recursive-sorted-keys, keep null, drop undefined, compact JSON.
  Byte-exact with the Python, Go, TypeScript, and Rust reference verifiers.
  """
  @spec canonicalize_map(map()) :: iodata()
  def canonicalize_map(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map(fn {k, v} ->
      [Jason.encode!(k), ":", canonicalize_value(v)]
    end)
    |> IO.iodata_to_binary()
    |> (&("{" <> &1 <> "}")).()
  end

  defp canonicalize_value(nil), do: "null"
  defp canonicalize_value(true), do: "true"
  defp canonicalize_value(false), do: "false"
  defp canonicalize_value(v) when is_binary(v), do: Jason.encode!(v)
  defp canonicalize_value(v) when is_integer(v), do: Integer.to_string(v)
  defp canonicalize_value(v) when is_float(v), do: Float.to_string(v)
  defp canonicalize_value(v) when is_map(v), do: canonicalize_map(v)
  defp canonicalize_value(v) when is_list(v) do
    items = v |> Enum.map(&canonicalize_value/1) |> Enum.join(",")
    "[" <> items <> "]"
  end
end
