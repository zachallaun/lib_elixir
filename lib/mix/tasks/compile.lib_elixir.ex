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
        info("Compiling #{inspect(module)} (Elixir #{ref})")

        # clean_lib(module)
        compile(module, ref, targets)

        manifest
        |> put_in([:libs, module], %{ref: ref, targets: targets})
        |> write_manifest!()

        :ok

      _ ->
        info("Nothing to compile")
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
    archive_path = Artifact.download_elixir_archive!(ref)

    with_tmp_dir(fn tmp_dir ->
      Artifact.extract_archive!(archive_path, tmp_dir)
      # The only top-level directory after extracting the archive
      # is the Elixir source directory
      [source_dir] = File.ls!(tmp_dir)
      source_dir = Path.join(tmp_dir, source_dir)

      target_dir = Path.join([Mix.Project.build_path(), "lib", "lib_elixir", "ebin"])

      ebin_path = compile_elixir_stdlib!(source_dir)

      Namespace.transform!(targets, module, ebin_path, target_dir)
    end)

    :ok
  end

  defp compile_elixir_stdlib!(source_dir) do
    case System.cmd("make", ["clean", "erlang", "app", "stdlib"], cd: source_dir) do
      {_, 0} ->
        ebin_path = Path.join([source_dir, "lib", "elixir", "ebin"])

        # Remove `lib_iex.beam`; we don't want it.
        ebin_path |> Path.join("*iex.beam") |> Path.wildcard() |> Enum.each(&File.rm!/1)

        ebin_path

      {output, non_zero} ->
        raise CompileError,
          message: "Unable to build Elixir, make returned:\nexit: #{non_zero}\noutput: #{output}"
    end
  end

  defp with_tmp_dir(fun) when is_function(fun, 1) do
    rand_string = 8 |> :crypto.strong_rand_bytes() |> Base.encode32(case: :lower, padding: false)
    tmp_dir = Path.join([File.cwd!(), "tmp", rand_string])

    File.mkdir_p!(tmp_dir)

    try do
      fun.(tmp_dir)
    after
      File.rm_rf!(tmp_dir)
    end
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
    with {:ok, [{module, ref, targets}]} <- Keyword.fetch(config(), :lib_elixir) do
      manifest_lib = Map.get(manifest.libs, module, %{ref: nil, targets: []})

      if manifest_lib.ref == ref and targets -- manifest_lib.targets == [] do
        :error
      else
        {:ok, {module, ref, targets}}
      end
    end
  end

  defp info(message) do
    Mix.shell().info("[lib_elixir] #{message}")
  end

  defp config do
    Mix.Project.config()
  end
end
