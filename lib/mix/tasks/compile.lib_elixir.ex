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
    case required_lib_elixir() do
      {:ok, manifest} ->
        compile!(manifest)
        write_manifest!(manifest)

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

  def compile!(manifest) do
    artifact = Artifact.prepare!(manifest.ref)

    target_directory = Mix.Project.compile_path()

    Namespace.transform!(
      manifest.module,
      manifest.targets,
      manifest.exclusions,
      artifact.ebin_directory,
      target_directory
    )

    :ok
  end

  defp required_lib_elixir do
    with {:ok, config} <- Keyword.fetch(config(), :lib_elixir) do
      unexpected = Keyword.drop(config, [:namespace, :ref, :include, :exclude])

      unless unexpected == [] do
        raise ArgumentError,
              "`:lib_elixir` was configured with unexpected keys: #{inspect(unexpected)}"
      end

      module = config[:namespace] || raise ":lib_elixir config must have `:namespace`"
      ref = config[:ref] || raise ":lib_elixir config must have `:ref`"
      targets = config[:include] || raise ":lib_elixir config must have `:include`"
      exclusions = Keyword.get(config, :exclude, [])

      old_manifest = get_manifest()
      new_manifest = new_manifest(module, ref, targets, exclusions)

      if hash(old_manifest) == hash(new_manifest) do
        :error
      else
        {:ok, new_manifest}
      end
    end
  end

  defp config do
    Mix.Project.config()
  end

  defp manifest_path do
    Path.join(Mix.Project.app_path(), ".lib_elixir")
  end

  defp get_manifest do
    manifest_path()
    |> File.read!()
    |> :erlang.binary_to_term()
  rescue
    _ -> new_manifest()
  end

  defp write_manifest!(manifest) do
    File.write!(manifest_path(), :erlang.term_to_binary(manifest))
  end

  defp new_manifest(module \\ nil, ref \\ nil, targets \\ [], exclusions \\ []) do
    hash = hash(module, ref, targets, exclusions)

    %{
      module: module,
      ref: ref,
      targets: targets,
      exclusions: exclusions,
      hash: hash
    }
  end

  defp hash(%{hash: hash}) when hash != nil, do: hash

  defp hash(module, ref, targets, exclusions) do
    :erlang.phash2([
      module,
      ref,
      Enum.sort(targets),
      Enum.sort(exclusions)
    ])
  end
end
