defmodule LibElixir.Integration do
  @moduledoc """
  Integration tests for `LibElixir`.
  """

  alias LibElixir.Integration.LibElixir.Macro

  def env do
    struct(Macro.Env, Map.from_struct(__ENV__))
  end
end
