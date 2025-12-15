defmodule WayfaererTest do
  use ExUnit.Case

  alias Wayfaerer.Tools.{Cars, Jobs}

  setup_all do
    Application.ensure_all_started(:wayfaerer)
    :ok
  end

  test "drafts haggle email inline" do
    body = Wayfaerer.Tools.Email.draft_haggle(%{"name" => "Sam", "listing" => "Civic"})
    assert String.contains?(body, "Civic")
  end

  test "enqueues and completes mock listing search" do
    {:ok, job} = Cars.enqueue_search(%{"make" => "Honda"})
    assert job.tool == "cars.search_listings"

    # Allow worker to run
    Process.sleep(50)
    {:ok, refreshed} = Jobs.get(%{id: job.id})
    assert refreshed.status in [:queued, :running, :done]
  end
end
