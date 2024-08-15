defmodule LibElixir.Namespace do
  @moduledoc false

  alias LibElixir.Namespace

  defstruct [:module, :source_dir, :target_dir, :known_module_names, :targets, :version]

  @ignore_module_names [Kernel, Access, List, Tuple, String, Regex] |> Enum.map(&to_string/1)
  @ignore_protocol_names [Inspect, Collectable, Enumerable, List.Chars, String.Chars]
                         |> Enum.map(&to_string/1)

  @doc """
  Recursively namespaces modules in the `targets` list using `module` as
  the namespace prefix, writing the transformed beams to `target_dir`.
  """
  def transform!(targets, module, source_dir, target_dir) do
    ns = new(module, source_dir, target_dir)

    :ok = Namespace.App.rewrite(:elixir, ns)

    Mix.shell().info("Namespacing modules (and their dependencies): #{inspect(targets)}")

    result =
      transform(targets, ns, fn _module, _namespaced, target_path, binary ->
        :ok = File.write!(target_path, binary, [:binary, :raw])
      end)

    Mix.shell().info("Namespacing complete")

    result
  end

  @doc """
  Recursively namespaces modules in the `targets` list using `module` as
  the namespace prefix.

  Calls `fun` with three arguments: `module, namespaced_module, target_path, binary`.
  """
  def transform(targets, module, source_dir, target_dir, fun)
      when is_list(targets) and is_atom(module) and is_function(fun, 4) do
    ns = new(module, source_dir, target_dir)
    transform(targets, ns, fun)
  end

  def transform(targets, %__MODULE__{} = ns, fun) do
    case Enum.reject(targets, &should_namespace?(ns, &1)) do
      [] ->
        :ok

      invalid ->
        raise ArgumentError, message: "cannot transform targets: #{inspect(invalid)}"
    end

    Namespace.Abstract.maybe_patch_elixir_erl_pass!(ns.version)
    fan_out_transform(targets, ns, fun)
  end

  defp fan_out_transform(targets, ns, fun, transformed \\ MapSet.new())

  defp fan_out_transform([], _ns, _fun, transformed) do
    Enum.to_list(transformed)
  end

  defp fan_out_transform(targets, ns, fun, transformed) do
    namespace_target =
      fn target ->
        if target in transformed do
          MapSet.new()
        else
          forms = ns |> source_path(target) |> Namespace.Abstract.read!()
          {rewritten, new_deps} = Namespace.Abstract.rewrite(forms, ns)
          {:ok, namespaced, binary} = Namespace.Abstract.compile(rewritten)

          fun.(target, namespaced, target_path(ns, namespaced), binary)

          new_deps
        end
      end

    deps =
      targets
      |> Task.async_stream(namespace_target, timeout: :infinity)
      |> Enum.reduce(MapSet.new(), fn {:ok, new_deps}, deps ->
        MapSet.union(deps, new_deps)
      end)

    transformed = MapSet.union(transformed, MapSet.new(targets))

    deps
    |> MapSet.difference(transformed)
    |> Enum.to_list()
    |> fan_out_transform(ns, fun, transformed)
  end

  def new(module, source_dir, target_dir) do
    known_module_names =
      source_dir
      |> Path.join("*")
      |> Path.wildcard()
      |> Enum.map(fn path ->
        path |> Path.basename() |> Path.rootname()
      end)
      |> MapSet.new()

    %__MODULE__{
      module: module,
      source_dir: source_dir,
      target_dir: target_dir,
      known_module_names: known_module_names,
      version: Namespace.Versions.fetch_version!(source_dir)
    }
  end

  def source_path(%__MODULE__{} = ns, module, ext \\ "beam") do
    module_name = to_string(module)
    ns.source_dir |> Path.join("#{module_name}.#{ext}") |> Path.expand()
  end

  def target_path(%__MODULE__{} = ns, namespaced_module, ext \\ "beam") do
    ns.target_dir |> Path.join("#{namespaced_module}.#{ext}") |> Path.expand()
  end

  def module_kind(module) when is_atom(module), do: module |> to_string() |> module_kind()
  def module_kind("Elixir." <> _), do: :elixir
  def module_kind(_), do: :erlang

  def should_namespace?(%__MODULE__{} = ns, module) do
    module_name = to_string(module)
    module_name in ns.known_module_names and not should_ignore?(module_name)
  end

  defp should_ignore?(module_name) when is_binary(module_name) do
    module_name in @ignore_module_names or protocol_or_impl?(module_name)
  end

  # special cases
  defp protocol_or_impl?("Elixir.Inspect.Opts"), do: false
  defp protocol_or_impl?("Elixir.Inspect.Algebra"), do: false

  for protocol <- @ignore_protocol_names do
    defp protocol_or_impl?(unquote(protocol)), do: true
    defp protocol_or_impl?(unquote(protocol) <> "." <> _), do: true
  end

  defp protocol_or_impl?(_), do: false

  def namespace_module(%__MODULE__{} = ns, module) do
    case module_kind(module) do
      :elixir -> Module.concat([ns.module, module])
      :erlang -> namespace_erlang(ns, module)
    end
  end

  defp namespace_erlang(%__MODULE__{} = ns, module) do
    prefix =
      ns.module
      |> Macro.underscore()
      |> String.replace("/", "_")

    case to_string(module) do
      "elixir" <> rest -> :"#{prefix}#{rest}"
      module -> :"#{prefix}_#{module}"
    end
  end
end
