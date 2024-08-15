defmodule LibElixir.NamespaceTest do
  use ExUnit.Case
  use Mneme

  alias LibElixir.Namespace

  @beams Path.relative_to_cwd("test/beams/elixir-1.17.2")

  setup_all do
    start_supervised!(Patch.Supervisor)
    Patch.patch(Namespace.Versions, :fetch_version!, Version.parse!("1.17.2"))
    [namespace: Namespace.new(Test.LibElixir, @beams, Path.join(@beams, "target"))]
  end

  describe "transform/5" do
    test "transforms each target and its dependencies once" do
      source_dir = @beams
      target_dir = Path.join(@beams, "target")
      test_pid = self()

      fun = fn mod, _namespaced, _target_path, _binary ->
        send(test_pid, {:namespaced, mod})
      end

      {transformed, _} =
        ExUnit.CaptureLog.with_log(fn ->
          Namespace.transform([Code], Test.LibElixir, source_dir, target_dir, fun)
        end)

      assert is_list(transformed)
      assert length(transformed) == length(collect_namespaced())
    end

    defp collect_namespaced(mods \\ []) do
      receive do
        {:namespaced, mod} -> collect_namespaced([mod | mods])
      after
        0 -> mods
      end
    end
  end

  describe "module_kind/1" do
    test "differentiates between Elixir and Erlang modules" do
      auto_assert :elixir <- Namespace.module_kind(SomeModule)
      auto_assert :erlang <- Namespace.module_kind(:some_other_module)

      %{elixir: elixir_modules, erlang: erlang_modules} =
        @beams
        |> Path.join("*")
        |> Path.wildcard()
        |> Enum.map(fn path ->
          module = path |> Path.basename() |> Path.rootname() |> String.to_atom()
          {Namespace.module_kind(module), module}
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

      auto_assert 223 <- length(elixir_modules)
      auto_assert 36 <- length(erlang_modules)
    end
  end

  describe "should_namespace?/2" do
    test "returns true for non-protocol Elixir modules", %{namespace: ns} do
      auto_assert true <- Namespace.should_namespace?(ns, Code)
      auto_assert true <- Namespace.should_namespace?(ns, Inspect.Opts)
    end

    test "returns false for protocols and protocol implementations", %{namespace: ns} do
      auto_assert false <- Namespace.should_namespace?(ns, Inspect)
      auto_assert false <- Namespace.should_namespace?(ns, Inspect.Atom)

      auto_assert false <- Namespace.should_namespace?(ns, Collectable)
      auto_assert false <- Namespace.should_namespace?(ns, Collectable.List)

      auto_assert false <- Namespace.should_namespace?(ns, Enumerable)
      auto_assert false <- Namespace.should_namespace?(ns, Enumerable.Map)

      auto_assert false <- Namespace.should_namespace?(ns, List.Chars)
      auto_assert false <- Namespace.should_namespace?(ns, List.Chars.String)

      auto_assert false <- Namespace.should_namespace?(ns, String.Chars)
      auto_assert false <- Namespace.should_namespace?(ns, String.Chars.Version.Requirement)
    end

    test "returns false for Kernel", %{namespace: ns} do
      auto_assert false <- Namespace.should_namespace?(ns, Kernel)
    end
  end

  describe "namespace_module/2" do
    test "namespaces Elixir modules", %{namespace: ns} do
      auto_assert Test.LibElixir.Code <- Namespace.namespace_module(ns, Code)
      auto_assert Test.LibElixir.List.Chars <- Namespace.namespace_module(ns, List.Chars)
    end

    test "namespaces Erlang modules, replacing the leading elixir", %{namespace: ns} do
      auto_assert :test_lib_elixir <- Namespace.namespace_module(ns, :elixir)
      auto_assert :test_lib_elixir_foo <- Namespace.namespace_module(ns, :elixir_foo)
      auto_assert :test_lib_elixir_foo <- Namespace.namespace_module(ns, :foo)
      auto_assert :test_lib_elixir_foo_bar <- Namespace.namespace_module(ns, :foo_bar)
    end
  end

  describe "source_path/2" do
    test "returns the absolute path for a known module", %{namespace: ns} do
      code_path = Namespace.source_path(ns, Code)
      assert String.ends_with?(code_path, "/test/beams/elixir-1.17.2/Elixir.Code.beam")

      tokenizer_path = Namespace.source_path(ns, :elixir_tokenizer)
      assert String.ends_with?(tokenizer_path, "/test/beams/elixir-1.17.2/elixir_tokenizer.beam")
    end
  end
end
