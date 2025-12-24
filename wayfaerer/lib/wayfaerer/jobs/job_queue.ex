defmodule Wayfaerer.Jobs.JobQueue do
  @moduledoc """
  GenServer responsible for enqueuing jobs and coordinating workers.
  """

  use GenServer

  alias Wayfaerer.Jobs.{Idempotency, Worker, WorkerSupervisor}
  alias Wayfaerer.Store

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def enqueue(tool, args, opts \\ []) do
    GenServer.call(__MODULE__, {:enqueue, tool, args, opts})
  end

  def cancel(job_id) do
    GenServer.call(__MODULE__, {:cancel, job_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{workers: %{}}, {:continue, :hydrate}}
  end

  @impl true
  def handle_continue(:hydrate, state) do
    # No persisted queue yet; ETS is in-memory. Nothing to hydrate.
    {:noreply, state}
  end

  @impl true
  def handle_call({:enqueue, tool, args, opts}, _from, state) do
    idempotency_key = Idempotency.compute(tool, args)

    with :none <- Store.find_job_by_idempotency(idempotency_key, Idempotency.window_ms()) do
      job = build_job(tool, args, opts, idempotency_key)
      {:ok, _} = Store.put_job(job)
      :ok = Store.put_idempotency(idempotency_key, job.id, job.inserted_at)
      Store.log_event(job.id, :enqueued, %{tool: tool})
      {:ok, state} = start_worker(job, state)
      {:reply, {:ok, job}, state}
    else
      {:ok, job} ->
        {:reply, {:ok, job}, ensure_worker(job, state)}
    end
  end

  def handle_call({:cancel, job_id}, _from, state) do
    result =
      case Store.get_job(job_id) do
        {:ok, job} ->
          {updated, state} = cancel_job(job, state)
          {:ok, updated}

        :error ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info({:job_complete, job_id, status, result}, state) do
    case Store.get_job(job_id) do
      {:ok, job} ->
        updated = %{
          job
          | status: status,
            updated_at: System.system_time(:millisecond),
            attempts: job.attempts + 1
        }

        {:ok, _} = Store.update_job(updated)
        Store.put_result(job_id, result)
        Store.log_event(job_id, status, %{})
        {:noreply, %{state | workers: Map.delete(state.workers, job_id)}}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:job_failed, job, reason}, state) do
    updated = %{job | status: :failed, updated_at: System.system_time(:millisecond)}
    {:ok, _} = Store.update_job(updated)
    Store.put_result(job.id, %{error: inspect(reason)})
    Store.log_event(job.id, :failed, %{reason: inspect(reason)})
    {:noreply, %{state | workers: Map.delete(state.workers, job.id)}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {job_id, workers} = pop_worker_by_pid(state.workers, pid)
    if job_id, do: Store.log_event(job_id, :worker_down, %{})
    {:noreply, %{state | workers: workers}}
  end

  defp start_worker(job, state) do
    case DynamicSupervisor.start_child(WorkerSupervisor, {Worker, job}) do
      {:ok, pid} ->
        {:ok, %{state | workers: Map.put(state.workers, job.id, pid)}}

      {:error, {:already_started, pid}} ->
        {:ok, %{state | workers: Map.put(state.workers, job.id, pid)}}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  defp ensure_worker(%{status: status} = job, state) when status in [:queued, :running] do
    case Map.has_key?(state.workers, job.id) do
      true ->
        state

      false ->
        {:ok, state} = start_worker(job, state)
        state
    end
  end

  defp ensure_worker(_job, state), do: state

  defp build_job(tool, args, opts, idempotency_key) do
    now = System.system_time(:millisecond)

    %{
      id: Idempotency.new_job_id(),
      tool: tool,
      args: args,
      status: :queued,
      attempts: 0,
      max_attempts: Keyword.get(opts, :max_attempts, Wayfaerer.Jobs.Retry.max_attempts(opts)),
      timeout_ms: Keyword.get(opts, :timeout_ms, Wayfaerer.Jobs.Retry.timeout_ms(opts)),
      inserted_at: now,
      updated_at: now,
      idempotency_key: idempotency_key
    }
  end

  defp cancel_job(%{status: status} = job, state) when status in [:queued, :running] do
    updated = %{job | status: :canceled, updated_at: System.system_time(:millisecond)}
    {:ok, _} = Store.update_job(updated)
    Store.put_result(job.id, %{canceled: true})
    Store.log_event(job.id, :canceled, %{})

    case Map.fetch(state.workers, job.id) do
      {:ok, pid} -> Process.exit(pid, :cancel)
      :error -> :ok
    end

    {updated, %{state | workers: Map.delete(state.workers, job.id)}}
  end

  defp cancel_job(job, state), do: {job, state}

  defp pop_worker_by_pid(workers, pid) do
    case Enum.find(workers, fn {_job_id, worker_pid} -> worker_pid == pid end) do
      {job_id, _} -> {job_id, Map.delete(workers, job_id)}
      nil -> {nil, workers}
    end
  end
end
