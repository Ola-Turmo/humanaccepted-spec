defmodule ConformanceTest do
  use ExUnit.Case, async: false

  @vectors_dir Path.expand("../vectors/v1", __DIR__)

  setup_all do
    keys_path = Path.join(@vectors_dir, "keys.json")
    keys_content = File.read!(keys_path)
    {:ok, @keys = Jason.decode!(keys_content)}
  end

  test "all 4 conformance vectors pass" do
    {:ok, files} = File.ls(@vectors_dir)

    vectors =
      files
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.reject(&(&1 == "keys.json"))
      |> Enum.sort()

    assert length(vectors) >= 4, "expected at least 4 vectors, found #{length(vectors)}"

    results =
      Enum.map(vectors, fn filename ->
        path = Path.join(@vectors_dir, filename)
        receipt_json = File.read!(path)
        {:ok, receipt} = Jason.decode(receipt_json)
        receipt_name = receipt["name"]
        ke = @keys[receipt_name] || %{}
        pub_hex = ke["public_key_hex"]
        {:ok, pub} = HumanAccepted.Verifier.public_key_from_hex("ed25519:" <> pub_hex)
        verdict = HumanAccepted.Verifier.verify(receipt, pub)

        {filename, verdict}
      end)

    passed = Enum.count(results, fn {_, v} -> v.valid end)
    failed = Enum.count(results, fn {_, v} -> not v.valid end)

    Enum.each(results, fn {filename, v} ->
      if v.valid do
        IO.puts("  ✓ #{filename}: #{v.reason}")
      else
        IO.puts("  ✗ #{filename}: #{v.reason}")
      end
    end)

    IO.puts("")
    IO.puts("  #{passed}/#{length(vectors)} vectors pass, #{failed} failed.")

    assert failed == 0, "#{failed} vectors failed"
  end
end
