defmodule Wayfaerer.Tools.Jobs do
  @moduledoc """
  Inline helpers for querying and canceling jobs.
  """

  alias Wayfaerer.Jobs.JobQueue
  alias Wayfaerer.Store

  def get(%{"id" => id}), do: get(%{id: id})

  def get(%{id: job_id}) do
    with {:ok, job} <- Store.get_job(job_id) do
      result =
        case Store.get_result(job_id) do
          {:ok, res} -> res
          :error -> nil
        end

      {:ok, Map.put(job, :result, result)}
    else
      :error -> {:error, :not_found}
    end
  end

  def cancel(%{"id" => id}), do: cancel(%{id: id})

  def cancel(%{id: job_id}) do
    JobQueue.cancel(job_id)
  end
end
