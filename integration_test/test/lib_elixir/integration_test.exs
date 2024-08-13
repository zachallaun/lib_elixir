defmodule LibElixir.IntegrationTest do
  use ExUnit.Case

  test "has access to v1.17 Macro.Env features" do
    assert {:alias, LibElixir.V1_17.Macro.Env} = LibElixir.Integration.expand_macro_env_alias()
  end
end
