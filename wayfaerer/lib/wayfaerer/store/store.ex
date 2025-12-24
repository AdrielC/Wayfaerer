defmodule Wayfaerer.Store do
  @moduledoc """
  A thin abstraction over the configured storage backend.

  The ETS-backed store is the default implementation used by the application
  and is responsible for persisting job state, results, and audit trails.
  """

  @store Application.compile_env(:wayfaerer, :store, Wayfaerer.Store.EtsStore)

  def start_link(opts \\ []), do: @store.start_link(opts)
  def child_spec(opts), do: @store.child_spec(opts)

  def put_job(job), do: @store.put_job(job)
  def update_job(job), do: @store.update_job(job)
  def get_job(job_id), do: @store.get_job(job_id)

  def put_idempotency(key, job_id, inserted_at),
    do: @store.put_idempotency(key, job_id, inserted_at)

  def find_job_by_idempotency(key, window_ms), do: @store.find_job_by_idempotency(key, window_ms)
  def put_result(job_id, result), do: @store.put_result(job_id, result)
  def get_result(job_id), do: @store.get_result(job_id)
  def log_event(job_id, event, meta \\ %{}), do: @store.log_event(job_id, event, meta)
  def purge_idempotency(key), do: @store.purge_idempotency(key)
end
