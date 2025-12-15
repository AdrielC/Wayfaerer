defmodule Wayfaerer.Store.EtsStore do
  @moduledoc """
  ETS-backed store for jobs, results, idempotency keys, and audit logs.
  """

  use GenServer

  @tables [
    jobs: :wayfaerer_jobs,
    results: :wayfaerer_results,
    audit: :wayfaerer_audit,
    idempotency: :wayfaerer_idempotency
  ]

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put_job(job), do: GenServer.call(__MODULE__, {:put_job, job})
  def update_job(job), do: GenServer.call(__MODULE__, {:update_job, job})
  def get_job(job_id), do: GenServer.call(__MODULE__, {:get_job, job_id})

  def put_idempotency(key, job_id, inserted_at),
    do: GenServer.call(__MODULE__, {:put_idempotency, key, job_id, inserted_at})

  def find_job_by_idempotency(key, window_ms),
    do: GenServer.call(__MODULE__, {:find_job_by_idempotency, key, window_ms})

  def put_result(job_id, result), do: GenServer.call(__MODULE__, {:put_result, job_id, result})
  def get_result(job_id), do: GenServer.call(__MODULE__, {:get_result, job_id})

  def log_event(job_id, event, meta \\ %{}),
    do: GenServer.cast(__MODULE__, {:log_event, job_id, event, meta})

  def purge_idempotency(key), do: GenServer.call(__MODULE__, {:purge_idempotency, key})

  # Server callbacks
  @impl true
  def init(_opts) do
    Enum.each(@tables, &create_table/1)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put_job, job}, _from, state) do
    :ets.insert(table(:jobs), {job.id, job})
    {:reply, {:ok, job}, state}
  end

  def handle_call({:update_job, job}, _from, state) do
    :ets.insert(table(:jobs), {job.id, job})
    {:reply, {:ok, job}, state}
  end

  def handle_call({:get_job, job_id}, _from, state) do
    {:reply, lookup(table(:jobs), job_id), state}
  end

  def handle_call({:put_idempotency, key, job_id, inserted_at}, _from, state) do
    :ets.insert(table(:idempotency), {key, job_id, inserted_at})
    {:reply, :ok, state}
  end

  def handle_call({:find_job_by_idempotency, key, window_ms}, _from, state) do
    now = System.system_time(:millisecond)

    result =
      case :ets.lookup(table(:idempotency), key) do
        [{^key, job_id, inserted_at}] when now - inserted_at < window_ms ->
          case lookup(table(:jobs), job_id) do
            {:ok, job} -> {:ok, job}
            _ -> :none
          end

        _ ->
          :none
      end

    {:reply, result, state}
  end

  def handle_call({:put_result, job_id, result}, _from, state) do
    :ets.insert(table(:results), {job_id, result})
    {:reply, :ok, state}
  end

  def handle_call({:get_result, job_id}, _from, state) do
    {:reply, lookup(table(:results), job_id), state}
  end

  def handle_call({:purge_idempotency, key}, _from, state) do
    :ets.delete(table(:idempotency), key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:log_event, job_id, event, meta}, state) do
    :ets.insert(table(:audit), {System.system_time(:millisecond), job_id, event, meta})
    {:noreply, state}
  end

  defp table(name), do: Keyword.fetch!(@tables, name)

  defp create_table({_, name}) do
    :ets.new(name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])
  rescue
    ArgumentError -> :ok
  end

  defp lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      _ -> :error
    end
  end
end
