defmodule HumanAccepted.Verifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :humanaccepted_verifier,
      version: "0.1.0",
      description: "Reference verifier for the HumanAccepted receipt format v1.0.0 (Ed25519-signed receipts).",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:crypto]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Ed25519 verification via Erlang's :crypto module — no external dep
    ]
  end
end
