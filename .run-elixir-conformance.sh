#!/bin/bash
# Conformance test runner for the Elixir reference verifier.
# Requires Erlang/OTP 27+ and Elixir 1.18+ (built from source is fine; we did it).
# Uses Elixir's stdlib JSON module + Erlang/OTP's :crypto.verify/5 for Ed25519.
# No external dependencies.

set -e
cd "$(dirname "$0")/verifier/elixir"

# Recompile the verifier if needed
if [ ! -f _build/Elixir.HumanAccepted.Verifier.beam ] || [ lib/humanaccepted_verifier.ex -nt _build/Elixir.HumanAccepted.Verifier.beam ]; then
  echo "Compiling verifier..."
  elixirc -o _build lib/humanaccepted_verifier.ex
fi

# Run the conformance test runner
elixir -pa _build -e '
Application.ensure_all_started(:crypto)
root = "../../vectors/v1"
keys = File.read!(Path.join(root, "keys.json")) |> JSON.decode!()
files = Path.wildcard(Path.join(root, "*.json")) |> Enum.reject(&String.contains?(&1, "keys.json"))
files = Enum.sort(files)
IO.puts("Running conformance vectors from #{root}")
IO.puts("Keys file: #{Path.join(root, "keys.json")} (#{map_size(keys)} entries)")
IO.puts("")

{passed, failed} = Enum.reduce(files, {0, 0}, fn path, {p, f} ->
  filename = Path.basename(path)
  receipt = File.read!(path) |> JSON.decode!()
  receipt_name = receipt["name"]
  pub_hex = Map.fetch!(keys, receipt_name)["public_key_hex"]
  {:ok, pub} = HumanAccepted.Verifier.public_key_from_hex("ed25519:" <> pub_hex)
  verdict = HumanAccepted.Verifier.verify(receipt, pub)
  if verdict.valid do
    IO.puts("  PASS " <> filename <> ": " <> verdict.reason)
    {p + 1, f}
  else
    IO.puts("  FAIL " <> filename <> ": " <> verdict.reason)
    {p, f + 1}
  end
end)
total = passed + failed
IO.puts("")
IO.puts("  " <> Integer.to_string(passed) <> "/" <> Integer.to_string(total) <> " vectors pass, " <> Integer.to_string(failed) <> " failed.")
if failed > 0, do: System.halt(1)
'
