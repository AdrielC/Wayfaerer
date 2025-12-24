defmodule Wayfaerer.Jobs.Idempotency do
  @moduledoc """
  Utilities for computing idempotency keys and generating stable job identifiers.
  """

  @window_ms 5 * 60 * 1000

  def window_ms, do: @window_ms

  def compute(tool, args) do
    payload = {tool, args}

    :crypto.hash(:sha256, :erlang.term_to_binary(payload))
    |> Base.encode16(case: :lower)
  end

  def new_job_id do
    binary = :crypto.strong_rand_bytes(12)
    Base.encode16(binary, case: :lower)
  end
end
