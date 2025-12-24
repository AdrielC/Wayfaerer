defmodule Wayfaerer.Jobs.Retry do
  @moduledoc """
  Retry and backoff helpers for workers.
  """

  @default_attempts 3
  @default_timeout 30_000

  def max_attempts(opts), do: Keyword.get(opts, :max_attempts, @default_attempts)
  def timeout_ms(opts), do: Keyword.get(opts, :timeout_ms, @default_timeout)

  def backoff_ms(attempt) when attempt <= 1, do: 500
  def backoff_ms(attempt), do: trunc(:math.pow(2, attempt - 1) * 500)
end
