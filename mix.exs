defmodule LibElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :lib_elixir,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [exclude: [Mix, :crypto, :ssl, :public_key, :httpc]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger, :sasl, :inets, :ssl]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:patch, "~> 0.13.1"},
      {:castore, "~> 0.1 or ~> 1.0", optional: true},
      {:mneme, ">= 0.0.0", only: [:dev, :test]}
    ]
  end
end
