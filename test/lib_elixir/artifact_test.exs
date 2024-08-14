defmodule LibElixir.ArtifactTest do
  use ExUnit.Case, async: true
  use Mneme

  alias LibElixir.Artifact

  test "ref_kind/1" do
    auto_assert :precompiled <- Artifact.ref_kind("v1.17.2")
    auto_assert :source <- Artifact.ref_kind("main")
    auto_assert :source <- Artifact.ref_kind("12345678")
  end

  test "extract_zip!/1 raises for non-.zip paths" do
    auto_assert_raise ArgumentError, "expected .zip, got: any/path/not_zip.tar.gz", fn ->
      Artifact.extract_zip!("any/path/not_zip.tar.gz", "/tmp")
    end
  end
end
