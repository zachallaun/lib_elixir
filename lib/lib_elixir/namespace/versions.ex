defmodule LibElixir.Namespace.Versions do
  @moduledoc false

  # This function lives here so that we can patch it
  # during testing without encountering GenServer
  # timeout errors on other functions in Namespace.
  def fetch_version!(source_dir) do
    [source_dir, "..", "..", "..", "VERSION"]
    |> Path.join()
    |> File.read!()
    |> String.trim()
    |> Version.parse!()
  end
end
