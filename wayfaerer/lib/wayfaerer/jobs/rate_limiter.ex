defmodule Wayfaerer.Jobs.RateLimiter do
  @moduledoc """
  Sliding-window rate limiter to protect external providers.
  """

  use GenServer

  @default_limit 5
  @default_interval 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def request(key, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    interval = Keyword.get(opts, :interval, @default_interval)
    GenServer.call(__MODULE__, {:request, key, limit, interval})
  end

  @impl true
  def init(_opts) do
    {:ok, %{windows: %{}}}
  end

  @impl true
  def handle_call({:request, key, limit, interval}, _from, state) do
    now = System.system_time(:millisecond)
    window_start = now - interval

    timestamps = Map.get(state.windows, key, [])
    active = Enum.filter(timestamps, &(&1 >= window_start))

    {reply, updated} =
      if length(active) < limit do
        {:ok, %{state | windows: Map.put(state.windows, key, [now | active])}}
      else
        oldest = Enum.min(active)
        wait = interval - (now - oldest)
        {{:wait, wait}, state}
      end

    {:reply, reply, updated}
  end
end
