defmodule LibElixir.Integration.MixProject do
  use Mix.Project

  def project do
    [
      app: :lib_elixir_integration,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:lib_elixir] ++ Mix.compilers(),
      lib_elixir: lib_elixir()
    ]
  end

  defp lib_elixir do
    ref = System.get_env("LIB_ELIXIR_REF", "v1.17.2")

    [
      namespace: LibElixir.Integration.LibElixir,
      modules: [Macro.Env],
      ref: ref
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
