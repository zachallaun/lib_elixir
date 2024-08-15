defmodule LibElixir.Artifact do
  @moduledoc false

  alias LibElixir.Downloader
  alias LibElixir.Logger

  @enforce_keys [:ref, :otp]
  defstruct [:ref, :otp, :source_zip_path, :compiled_source_directory, :ebin_directory]

  @source_base_url "https://github.com/elixir-lang/elixir/archive"
  @precompiled_base_url "https://builds.hex.pm/builds/elixir"

  @doc false
  def new(ref) do
    %__MODULE__{
      ref: ref,
      otp: System.otp_release()
    }
    |> set_existing_paths()
  end

  @doc """
  Ensures that `artifact.ebin_directory` is set, downloading and
  compiling Elixir if necessary.

  If a download is required, this function will prefer to download a
  precompiled Elixir. Otherwise, it will download and compile the Elixir
  source.
  """
  def prepare!(ref) when is_binary(ref) do
    artifact = new(ref)

    if ebin_cached?(artifact) do
      Logger.debug("compiled source cached: #{artifact.compiled_source_directory}")
      artifact
    else
      case ref_kind(artifact.ref) do
        :precompiled ->
          download_precompiled!(artifact)

        :source ->
          download_and_compile_source!(artifact)
      end
    end
  end

  defp source_cached?(%__MODULE__{source_zip_path: nil}), do: false
  defp source_cached?(%__MODULE__{}), do: true

  defp ebin_cached?(%__MODULE__{ebin_directory: nil}), do: false
  defp ebin_cached?(%__MODULE__{}), do: true

  defp set_existing_paths(%__MODULE__{} = artifact) do
    artifact
    |> set_if_exists(:source_zip_path, source_zip_path(artifact))
    |> set_if_exists(:compiled_source_directory, compiled_source_directory(artifact))
    |> set_if_exists(:ebin_directory, ebin_directory(artifact))
  end

  defp set_if_exists(%__MODULE__{} = artifact, key, path) do
    if exists?(path) do
      Logger.debug("setting #{key}: #{path}")
      Map.replace!(artifact, key, path)
    else
      artifact
    end
  end

  defp source_zip_path(%__MODULE__{} = artifact) do
    cache_path("archives", "#{artifact.ref}.zip")
  end

  defp compiled_source_directory(%__MODULE__{} = artifact) do
    cache_path(["compiled", artifact.otp, artifact.ref])
  end

  defp ebin_directory(%__MODULE__{} = artifact) do
    Path.join([compiled_source_directory(artifact), "lib", "elixir", "ebin"])
  end

  defp cache_path(subdir) do
    path = Path.join([cache_dir()] ++ List.wrap(subdir))
    File.mkdir_p!(path)
    path
  end

  defp cache_path(subdir, file) do
    cache_dir = cache_path(subdir)
    Path.join(cache_dir, file)
  end

  defp cache_dir do
    cache_dir = :filename.basedir(:user_cache, "lib_elixir")
    File.mkdir_p!(cache_dir)
    cache_dir
  end

  defp download_precompiled!(%__MODULE__{} = artifact, include_otp? \\ true) do
    compiled_source_directory = compiled_source_directory(artifact)
    zip_path = Path.join(compiled_source_directory, "#{artifact.ref}.zip")

    url =
      if include_otp? do
        Path.join(@precompiled_base_url, "#{artifact.ref}-otp-#{artifact.otp}.zip")
      else
        Path.join(@precompiled_base_url, "#{artifact.ref}.zip")
      end

    Logger.debug("downloading precompiled: #{url}")

    Application.ensure_all_started(:req)

    try do
      case Downloader.download(url) do
        {:ok, content} ->
          File.write!(zip_path, content)
          extract_zip!(zip_path, compiled_source_directory)
          set_existing_paths(artifact)

        _ ->
          if include_otp? do
            Logger.debug("downloading precompiled failed, trying without otp")
            download_precompiled!(artifact, false)
          else
            Logger.debug("downloading precompiled failed, falling back to source")
            download_and_compile_source!(artifact)
          end
      end
    after
      File.rm(zip_path)
    end
  end

  defp download_and_compile_source!(%__MODULE__{} = artifact) do
    if source_cached?(artifact) do
      compile_source!(artifact)
    else
      artifact
      |> download_source!()
      |> compile_source!()
    end
  end

  defp download_source!(%__MODULE__{} = artifact) do
    source_zip_path = source_zip_path(artifact)
    source_zip_url = Path.join(@source_base_url, "#{artifact.ref}.zip")

    Application.ensure_all_started(:req)

    Logger.debug("downloading source: #{source_zip_url}")
    {:ok, content} = Downloader.download(source_zip_url)
    File.write!(source_zip_path, content)

    set_existing_paths(artifact)
  end

  defp compile_source!(%__MODULE__{} = artifact) do
    compiled_source_directory = compiled_source_directory(artifact)

    # source zip contains one top-level directory; we copy its contents
    # into the source directory and then delete it.
    extract_zip!(artifact.source_zip_path, compiled_source_directory)
    [inner] = File.ls!(compiled_source_directory)
    inner_directory = Path.join(compiled_source_directory, inner)
    File.cp_r!(inner_directory, compiled_source_directory)
    File.rm_rf!(inner_directory)

    try do
      compile_elixir_stdlib!(compiled_source_directory)
      set_existing_paths(artifact)
    rescue
      e ->
        # TODO: this needs to be better
        # in the event of an error, make sure the precompiled cache is
        # deleted so that we try to compile it again next time
        Logger.debug("compilation failed, deleting: #{compiled_source_directory}")
        File.rm_rf!(compiled_source_directory)
        reraise e, __STACKTRACE__
    end
  end

  defp compile_elixir_stdlib!(source_dir) do
    Logger.debug("compiling source: #{source_dir}")

    case System.cmd("make", ["clean", "erlang", "app", "stdlib"], cd: source_dir) do
      {_, 0} ->
        ebin_path = Path.join([source_dir, "lib", "elixir", "ebin"])

        # Remove `lib_iex.beam`; we don't want it.
        ebin_path |> Path.join("*iex.beam") |> Path.wildcard() |> Enum.each(&File.rm!/1)

        :ok

      {_, non_zero} ->
        Logger.error("unable to build Elixir, make exited #{non_zero}")
        raise CompileError
    end
  end

  @doc false
  def exists?(artifact_path) do
    case File.stat(artifact_path) do
      {:ok, %File.Stat{type: :directory}} ->
        File.ls!(artifact_path) != []

      {:ok, %File.Stat{size: size}} when size > 0 ->
        true

      _ ->
        false
    end
  end

  @doc false
  def ref_kind(ref) do
    if ref =~ ~r/v\d+\.\d+\.\d+/ do
      :precompiled
    else
      :source
    end
  end

  @doc false
  def extract_zip!(zip_path, directory) do
    unless String.ends_with?(zip_path, ".zip") do
      raise ArgumentError, "expected .zip, got: #{zip_path}"
    end

    File.mkdir_p!(directory)
    {:ok, _} = :zip.extract(String.to_charlist(zip_path), cwd: String.to_charlist(directory))
    :ok
  end
end
