defmodule Wayfaerer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Finch, name: Wayfaerer.Finch},
        {Wayfaerer.Store, []},
        {Wayfaerer.Jobs.RateLimiter, []},
        {Wayfaerer.Jobs.WorkerSupervisor, []},
        {Wayfaerer.Jobs.JobQueue, []}
      ]
      |> maybe_enable_mcp()

    opts = [strategy: :one_for_one, name: Wayfaerer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_enable_mcp(children) do
    if Application.get_env(:wayfaerer, :enable_mcp, Mix.env() != :test) do
      children ++ [{Wayfaerer.McpServer, []}]
    else
      children
    end
  end
end
