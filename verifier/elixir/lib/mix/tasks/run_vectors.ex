defmodule Mix.Tasks.RunVectors do
  @moduledoc """
  Run the conformance test runner from the command line.
  `mix run_vectors` walks vectors/v1/, calls verify() on each, and
  prints a pass/fail summary. Exits with code 1 on any failure.
  """
  use Mix.Task

  @shortdoc "Run conformance test vectors"
  @vectors_dir "vectors/v1"

  @impl Mix.Task
  def run(_args) do
    keys_path = Path.join(@vectors_dir, "keys.json")
    {:ok, keys_json} = File.read(keys_path)
    {:ok, keys} = Jason.decode(keys_json)

    {:ok, files} = File.ls(@vectors_dir)
    vectors =
      files
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.reject(&(&1 == "keys.json"))
      |> Enum.sort()

    IO.puts("Running conformance vectors from #{@vectors_dir}")
    IO.puts("Keys file: #{keys_path} (#{map_size(keys)} entries)")
    IO.puts("")

    {passed, failed} =
      Enum.reduce(vectors, {0, 0}, fn filename, {p, f} ->
        path = Path.join(@vectors_dir, filename)
        {:ok, receipt_json} = File.read(path)
        {:ok, receipt} = Jason.decode(receipt_json)
        receipt_name = receipt["name"]
        ke = Map.get(keys, receipt_name, %{})
        pub_hex = ke["public_key_hex"]
        {:ok, pub} = HumanAccepted.Verifier.public_key_from_hex("ed25519:" <> pub_hex)
        verdict = HumanAccepted.Verifier.verify(receipt, pub)

        if verdict.valid do
          IO.puts("  ✓ #{filename}: #{verdict.reason}")
          {p + 1, f}
        else
          IO.puts("  ✗ #{filename}: #{verdict.reason}")
          {p, f + 1}
        end
      end)

    total = passed + failed
    IO.puts("")
    IO.puts("  #{passed}/#{total} vectors pass, #{failed} failed.")

    if failed > 0, do: System.halt(1)
  end
end
