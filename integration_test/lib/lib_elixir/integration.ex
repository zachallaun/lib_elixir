defmodule LibElixir.Integration do
  @moduledoc """
  Integration tests for `LibElixir`.
  """

  alias LibElixir.V1_17.Macro

  def expand_macro_env_alias do
    env = struct(Macro.Env, Map.from_struct(__ENV__))
    Macro.Env.expand_alias(env, [], [:Macro, :Env])
  end
end
