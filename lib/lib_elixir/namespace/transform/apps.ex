defmodule LibElixir.Namespace.Transform.Apps do
  @moduledoc """
  Applies namespacing to all modules defined in .app files
  """
  alias LibElixir.Namespace
  alias LibElixir.Namespace.Transform

  def apply_to_all(%Namespace{} = ns) do
    ns.source_dir
    |> find_app_files()
    |> tap(fn app_files ->
      Mix.Shell.IO.info("Rewriting #{length(app_files)} app files")
    end)
    |> Enum.each(&apply_to_file(&1, ns))
  end

  def apply_to_file(file_path, %Namespace{} = ns) do
    app_name =
      file_path
      |> Path.basename()
      |> Path.rootname()
      |> String.to_atom()

    namespaced_app = Namespace.namespace_module(ns, app_name)

    target_path = Namespace.target_path(ns, namespaced_app, "app")

    with {:ok, app_definition} <- Transform.Erlang.path_to_term(file_path),
         {:ok, converted} <- convert(app_definition, ns) do
      File.write(target_path, converted)
    end
  end

  defp find_app_files(base_directory) do
    [base_directory, "**", "*.app"]
    |> Path.join()
    |> Path.wildcard()
  end

  defp convert(app_definition, ns) do
    erlang_terms =
      app_definition
      |> visit(ns)
      |> Transform.Erlang.term_to_string()

    {:ok, erlang_terms}
  end

  defp visit({:application, app_name, keys}, ns) do
    {:application, Namespace.namespace_module(ns, app_name), Enum.map(keys, &visit(&1, ns))}
  end

  defp visit({:applications, app_list}, ns) do
    {:applications, Enum.map(app_list, &Namespace.namespace_module(ns, &1))}
  end

  defp visit({:modules, module_list}, ns) do
    {:modules, Enum.map(module_list, &Namespace.namespace_module(ns, &1))}
  end

  defp visit({:description, desc}, _ns) do
    {:description, desc ++ ~c" namespaced by lib_elixir"}
  end

  defp visit({:mod, {module_name, args}}, ns) do
    {:mod, {Namespace.namespace_module(ns, module_name), args}}
  end

  defp visit(key_value, _ns) do
    key_value
  end
end
