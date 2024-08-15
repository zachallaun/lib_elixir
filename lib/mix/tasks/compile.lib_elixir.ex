defmodule Mix.Tasks.Compile.LibElixir do
  @moduledoc """
  A utility for generating namespaced core Elixir modules for any version.
  """

  use Mix.Task.Compiler

  alias LibElixir.Artifact
  alias LibElixir.Namespace

  require Logger

  @impl true
  def run(_args) do
    manifest = get_manifest()

    case required_lib_elixir(manifest) do
      {:ok, {module, ref, targets}} ->
        compile(module, ref, targets)

        manifest
        |> put_in([:libs, module], %{ref: ref, targets: targets})
        |> write_manifest!()

        :ok

      _ ->
        :noop
    end
  end

  @impl true
  def manifests do
    [manifest_path()]
  end

  @impl true
  def clean do
    File.rm(manifest_path())
    :ok
  end

  def compile(module, ref, targets) do
    artifact = Artifact.prepare!(ref)

    target_directory = Mix.Project.compile_path()

    Namespace.transform!(targets, module, artifact.ebin_directory, target_directory)

    :ok
  end

  defp manifest_path do
    Path.join(Mix.Project.app_path(), ".lib_elixir")
  end

  defp get_manifest do
    manifest_path()
    |> File.read!()
    |> :erlang.binary_to_term()
  rescue
    _ -> %{libs: %{}}
  end

  defp write_manifest!(manifest) do
    File.write!(manifest_path(), :erlang.term_to_binary(manifest))
  end

  defp required_lib_elixir(manifest) do
    with {:ok, config} <- Keyword.fetch(config(), :lib_elixir) do
      unexpected = Keyword.drop(config, [:namespace, :ref, :modules])

      unless unexpected == [] do
        raise ArgumentError,
              "`:lib_elixir` was configured with unexpected keys: #{inspect(unexpected)}"
      end

      module = config[:namespace] || raise ":lib_elixir config must have `:namespace`"
      ref = config[:ref] || raise ":lib_elixir config must have `:ref`"
      targets = config[:modules] || raise ":lib_elixir config must have `:modules`"

      manifest_lib = Map.get(manifest.libs, module, %{ref: nil, targets: []})

      if manifest_lib.ref == ref and targets -- manifest_lib.targets == [] do
        :error
      else
        {:ok, {module, ref, targets}}
      end
    end
  end

  defp config do
    Mix.Project.config()
  end
end
