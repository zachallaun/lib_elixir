defmodule LibElixir.IntegrationTest do
  use ExUnit.Case

  test "has access a compiled lib_elixir" do
    assert %LibElixir.Integration.LibElixir.Macro.Env{} = LibElixir.Integration.env()
  end
end
