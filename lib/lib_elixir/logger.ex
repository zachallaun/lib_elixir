defmodule LibElixir.Logger do
  @moduledoc false

  require Logger

  @doc """
  Logs a debug message if `LIB_ELIXIR_DEBUG` is set.
  """
  def debug(message) do
    debug_env = "LIB_ELIXIR_DEBUG" |> System.get_env("") |> String.downcase() |> String.trim()

    if debug_env in ["1", "true"] do
      Logger.debug("[lib_elixir] #{message}")
    end
  end

  @doc """
  Logs an error.
  """
  def error(message), do: Logger.error(message)
end
