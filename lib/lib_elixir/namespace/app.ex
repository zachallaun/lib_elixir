defmodule LibElixir.Namespace.App do
  @moduledoc false

  alias LibElixir.Namespace

  @doc """
  Reads and namespaces the given `app`, writing to the new target path.

  Returns the namespaced app name.
  """
  def rewrite(app, %Namespace{} = ns) do
    namespaced_app = Namespace.namespace_module(ns, app)
    source_path = Namespace.source_path(ns, app, "app")
    target_path = Namespace.target_path(ns, namespaced_app, "app")

    {:ok, [app_definition]} = :file.consult(source_path)
    rewritten = rewrite_app(app_definition, ns)

    File.write!(target_path, :io_lib.format(~c"~p.~n", [rewritten]))
  end

  defp rewrite_app({:application, app_name, keys}, ns) do
    {:application, Namespace.namespace_module(ns, app_name), Enum.map(keys, &rewrite_app(&1, ns))}
  end

  defp rewrite_app({:applications, app_list}, ns) do
    {:applications, Enum.map(app_list, &Namespace.namespace_module(ns, &1))}
  end

  defp rewrite_app({:modules, module_list}, ns) do
    {:modules, Enum.map(module_list, &Namespace.namespace_module(ns, &1))}
  end

  defp rewrite_app({:description, desc}, _ns) do
    {:description, desc ++ ~c" namespaced by lib_elixir"}
  end

  defp rewrite_app({:mod, {module_name, args}}, ns) do
    {:mod, {Namespace.namespace_module(ns, module_name), args}}
  end

  defp rewrite_app(key_value, _ns) do
    key_value
  end
end
