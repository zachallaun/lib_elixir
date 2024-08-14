defmodule LibElixir.Integration.MixProject do
  use Mix.Project

  def project do
    [
      app: :lib_elixir_integration,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:lib_elixir] ++ Mix.compilers(),
      lib_elixir: [
        namespace: LibElixir.V1_17,
        modules: [Macro.Env],
        ref: "v1.17.2"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:lib_elixir, path: "..", runtime: false}
    ]
  end
end
