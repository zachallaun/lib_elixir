defmodule LibElixir.Namespace.AbstractTest do
  use ExUnit.Case, async: true
  use Mneme

  alias LibElixir.Namespace
  alias LibElixir.Namespace.Abstract

  @beams Path.relative_to_cwd("test/beams/elixir-1.17.2")

  setup_all do
    [namespace: Namespace.new(Test.LibElixir, @beams, @beams)]
  end

  describe "rewrite/2" do
    test "extracts module dependencies", %{namespace: ns} do
      code_beam_path = Path.relative_to_cwd("test/beams/elixir-1.17.2/Elixir.Code.beam")

      auto_assert {_rewritten, dependencies} <-
                    code_beam_path |> Abstract.read!() |> Abstract.rewrite(ns)

      auto_assert [
                    ArgumentError,
                    Code,
                    Code.Formatter,
                    Code.Fragment,
                    Code.LoadError,
                    Code.Normalizer,
                    Enum,
                    Exception,
                    File,
                    Inspect.Algebra,
                    Kernel.ErrorHandler,
                    Keyword,
                    Macro,
                    Macro.Env,
                    Module.ParallelChecker,
                    Path,
                    Process,
                    RuntimeError,
                    String,
                    :elixir,
                    :elixir_code_server,
                    :elixir_compiler,
                    :elixir_config,
                    :elixir_errors
                  ] <- Enum.sort(dependencies)
    end
  end
end
