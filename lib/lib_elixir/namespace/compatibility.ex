defmodule LibElixir.Namespace.Compatibility do
  @moduledoc false

  @doc """
  Fetches the Elixir version from the `VERSION` file relative to `ebin_dir`.
  """
  def fetch_version!(ebin_dir) do
    [ebin_dir, "..", "..", "..", "VERSION"]
    |> Path.join()
    |> File.read!()
    |> String.trim()
    |> Version.parse!()
  end

  @doc """
  Rewrites abstract forms for better compatibility.
  """
  def rewrite_form(form) do
    form
    |> rewrite_atom_to_binary()
  end

  # Handles `atom_to_binary/1`, which wasn't introduced until OTP 23.0.
  #
  # Rewrites the abstract form call of `atom_to_binary(Foo)` to the
  # equivalent `atom_to_binary(Foo, utf8)`.
  defp rewrite_atom_to_binary({:call, anno, {:atom, _, :atom_to_binary} = atb, [arg1]}) do
    {:call, anno, atb, [arg1, {:atom, anno_to_line(anno), :utf8}]}
  end

  defp rewrite_atom_to_binary(other), do: other

  defp anno_to_line({line, _}), do: anno_to_line(line)
  defp anno_to_line(line) when is_integer(line) and line >= 0, do: line
  defp anno_to_line(_), do: 0

  @doc """
  Handles a change to the representation of bitstring modifiers in the
  debug_info chunk.

  In Elixir 1.15, bitstring modifiers changed their normalized AST
  representation from `<<x::integer()>>` to `<<x::integer>>`, which
  means `{modifier, meta, []}` became `{modifier, meta, nil}`. So, if
  we're compiling an Elixir > 1.15 on a runtime < 1.15, we wind up with
  function clause errors.

  This function monkey-patches `:elixir_erl_pass.extract_bit_type/2` if
  necessary to coerce the arguments into the correct form.

  Relevant PR: https://github.com/elixir-lang/elixir/pull/12055
  """
  def maybe_patch_elixir_erl_pass!(target_version) do
    if should_patch_elixir_erl_pass?(target_version) do
      patch_elixir_erl_pass!()
    end
  end

  defp patch_elixir_erl_pass! do
    :persistent_term.put({__MODULE__, :patched?}, true)

    Patch.Supervisor.start_link()

    Patch.patch(:elixir_erl_pass, :extract_bit_type, fn any, list ->
      try_extract_bit_type(any, list)
    end)

    :ok
  end

  defp try_extract_bit_type({name, meta, args}, list) do
    extract_bit_type({name, meta, args}, list)
  rescue
    _ ->
      try do
        case args do
          [] -> extract_bit_type({name, meta, nil}, list)
          nil -> extract_bit_type({name, meta, []}, list)
        end
      rescue
        e ->
          IO.inspect({args, list}, label: "failed on")
          reraise e, __STACKTRACE__
      end
  end

  defp extract_bit_type(x, list) do
    Patch.Mock.Naming.original(:elixir_erl_pass).extract_bit_type(x, list)
  end

  defp should_patch_elixir_erl_pass?(target_version) do
    already_patched? = :persistent_term.get({__MODULE__, :patched?}, false)
    current_version = Version.parse!(System.version())

    not already_patched? and
      ((current_version.minor < 15 and target_version.minor >= 15) or
         (current_version.minor >= 15 and target_version.minor < 15))
  end
end
