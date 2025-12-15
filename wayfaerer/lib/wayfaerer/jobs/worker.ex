defmodule Wayfaerer.Jobs.Worker do
  @moduledoc """
  Executes jobs with retries, timeouts, backoff, and rate limiting.
  """

  use GenServer, restart: :temporary

  alias Wayfaerer.Jobs.{RateLimiter, Retry}
  alias Wayfaerer.Store
  alias Wayfaerer.Tools.Cars

  def start_link(job) do
    GenServer.start_link(__MODULE__, job)
  end

  @impl true
  def init(job) do
    Process.flag(:trap_exit, true)
    {:ok, %{job: job}, {:continue, :process}}
  end

  @impl true
  def handle_continue(:process, %{job: job} = state) do
    Process.send_after(self(), :execute, 0)
    {:noreply, state}
  end

  @impl true
  def handle_info(:execute, %{job: job} = state) do
    case RateLimiter.request({job.tool, :global}) do
      :ok ->
        execute_job(job, state)

      {:wait, delay} ->
        Process.send_after(self(), :execute, delay)
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, _from, :cancel}, %{job: job} = state) do
    Store.log_event(job.id, :canceled, %{by: :signal})
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _from, reason}, state) do
    {:stop, reason, state}
  end

  defp execute_job(job, state) do
    running = %{job | status: :running, updated_at: System.system_time(:millisecond)}
    {:ok, _} = Store.update_job(running)
    Store.log_event(job.id, :started, %{})

    task = Task.async(fn -> perform_job(running) end)

    case Task.yield(task, job.timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, result}} ->
        send(Wayfaerer.Jobs.JobQueue, {:job_complete, job.id, :done, result})
        {:stop, :normal, state}

      {:ok, {:error, reason}} ->
        handle_retry(job, reason, state)

      nil ->
        handle_retry(job, :timeout, state)
    end
  end

  defp handle_retry(%{attempts: attempts, max_attempts: max_attempts} = job, reason, state) do
    if attempts + 1 >= max_attempts do
      send(Wayfaerer.Jobs.JobQueue, {:job_failed, %{job | attempts: attempts + 1}, reason})
      {:stop, :normal, state}
    else
      delay = Retry.backoff_ms(attempts + 1)
      Store.log_event(job.id, :retrying, %{after_ms: delay, reason: inspect(reason)})
      Process.send_after(self(), :execute, delay)
      {:noreply, %{state | job: %{job | attempts: attempts + 1}}}
    end
  end

  defp perform_job(%{tool: "cars.search_listings", args: args}) do
    {:ok, Cars.search_listings_job(args)}
  rescue
    error -> {:error, error}
  end

  defp perform_job(%{tool: "cars.decode_vin", args: args}) do
    {:ok, Cars.decode_vin_job(args)}
  rescue
    error -> {:error, error}
  end

  defp perform_job(%{tool: tool}) do
    {:error, {:unknown_tool, tool}}
  end
end
