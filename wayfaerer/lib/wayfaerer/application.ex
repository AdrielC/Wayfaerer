defmodule Wayfaerer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Wayfaerer.Finch},
      {Wayfaerer.Store, []},
      {Wayfaerer.Jobs.RateLimiter, []},
      {Wayfaerer.Jobs.WorkerSupervisor, []},
      {Wayfaerer.Jobs.JobQueue, []},
      {Wayfaerer.McpServer, []}
    ]

    opts = [strategy: :one_for_one, name: Wayfaerer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
