defmodule LibElixir.Namespace.Abstract.DefpRewriteForm do
  @moduledoc false

  @doc """
  Defines a clause of `defp rewrite_form(...)`, rewriting the instance
  of `module` within `form`.
  """
  defmacro defp_rewrite_form(form) do
    fun_name = :"rewrite-#{Macro.to_string(form)}"

    quote generated: true do
      defp rewrite_form(unquote(ignore_vars(form)) = form, acc) do
        unquote(fun_name)(form, acc)
      end

      defp unquote(fun_name)(unquote(form), {ns, deps}) do
        {var!(module), deps} = rewrite_module(var!(module), deps, ns)
        {unquote(form), {ns, deps}}
      end
    end
  end

  defp ignore_vars({:{}, meta, args}) do
    {:{}, meta, ignore_vars(args)}
  end

  defp ignore_vars({left, right}) do
    {ignore_vars(left), ignore_vars(right)}
  end

  defp ignore_vars(list) when is_list(list) do
    Enum.map(list, &ignore_vars/1)
  end

  defp ignore_vars({var, meta, context}) when is_atom(var) and is_atom(context) do
    {:_, meta, nil}
  end

  defp ignore_vars(other), do: other
end

defmodule LibElixir.Namespace.Abstract do
  @moduledoc false
  # https://www.erlang.org/doc/apps/erts/absform.html

  alias LibElixir.Namespace

  import LibElixir.Namespace.Abstract.DefpRewriteForm

  @doc """
  Reads abstract forms from the .beam file at `path`.
  """
  def read!(path) do
    with {:ok, {_orig_module, chunks}} <- :beam_lib.chunks(to_charlist(path), [:abstract_code]),
         {:raw_abstract_v1, forms} <- chunks[:abstract_code] do
      forms
    else
      _ ->
        raise "Could not read abstract forms from: #{path}"
    end
  catch
    :exit, reason ->
      LibElixir.Logger.error(
        "encountered exit (#{inspect(reason)}) while reading abstract code: #{path}"
      )

      exit(reason)
  end

  @doc """
  Compiles abstract forms into a binary beam.
  """
  def compile(forms) do
    :compile.forms(forms, [
      :return_errors,
      :no_spawn_compiler_process
    ])
  end

  @doc """
  Rewrites abstract forms, returning those forms and any module
  dependencies extracted.
  """
  def rewrite(abstract_forms, %Namespace{} = ns) when is_list(abstract_forms) do
    {forms, {_ns, deps}} =
      walk_abstract_forms(abstract_forms, {ns, MapSet.new()}, fn form, acc ->
        form
        |> Namespace.Compatibility.rewrite_form()
        |> rewrite_form(acc)
      end)

    {forms, deps}
  end

  defp walk_abstract_forms(abstract_forms, acc, fun) when is_list(abstract_forms) do
    {reverse_forms, acc} =
      Enum.reduce(abstract_forms, {[], acc}, fn form, {forms, acc} ->
        {form, acc} = fun.(form, acc)
        {form, acc} = walk_abstract_forms(form, acc, fun)
        {[form | forms], acc}
      end)

    {Enum.reverse(reverse_forms), acc}
  end

  defp walk_abstract_forms(abstract_forms, acc, fun) when is_tuple(abstract_forms) do
    [tag | rest] = Tuple.to_list(abstract_forms)
    {forms, acc} = walk_abstract_forms(rest, acc, fun)
    {List.to_tuple([tag | forms]), acc}
  end

  defp walk_abstract_forms(form, acc, _fun) do
    {form, acc}
  end

  defp_rewrite_form({:attribute, anno, :behaviour, module})
  defp_rewrite_form({:attribute, anno, :import, {module, funs}})
  defp_rewrite_form({:attribute, anno, :module, module})
  defp_rewrite_form({:attribute, anno, :record, {module, fields}})
  defp_rewrite_form({:for, module})
  defp_rewrite_form({:protocol, module})
  defp_rewrite_form({:record_field, anno, repr_1, module, repr_3})
  defp_rewrite_form({:atom, anno, module})
  defp_rewrite_form({:var, anno, module})
  defp_rewrite_form({:record, anno, module, fields})
  defp_rewrite_form({:record, anno, expr, module, fields})
  defp_rewrite_form({:user_type, anno, module, types})
  defp rewrite_form(form, acc), do: {form, acc}

  defp rewrite_module(module, deps, %Namespace{} = ns) do
    if Namespace.should_namespace?(ns, module) do
      {Namespace.namespace_module(ns, module), MapSet.put(deps, module)}
    else
      {module, deps}
    end
  end
end
