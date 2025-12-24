defmodule Wayfaerer.McpServer do
  @moduledoc """
  Minimal MCP server over stdio. Uses a non-blocking port to receive JSON-RPC style messages.
  """

  use GenServer

  alias Wayfaerer.Tools.{Cars, Email, Jobs}

  @tools [
    %{name: "cars.search_listings", mode: :job},
    %{name: "cars.decode_vin", mode: :job},
    %{name: "email.draft_haggle", mode: :inline},
    %{name: "jobs.get", mode: :inline},
    %{name: "jobs.cancel", mode: :inline}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    port = Port.open({:fd, 0, 1}, [:binary, :stream, {:line, 65_535}, :exit_status])
    {:ok, %{port: port}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    data
    |> String.trim()
    |> Jason.decode()
    |> case do
      {:ok, request} -> process_request(request, state)
      {:error, _} -> {:noreply, state}
    end
  end

  def handle_info({port, :closed}, %{port: port} = state) do
    {:stop, :normal, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp process_request(%{"id" => id, "method" => "list_tools"}, state) do
    reply(id, %{tools: Enum.map(@tools, &tool_descriptor/1)}, state)
  end

  defp process_request(
         %{
           "id" => id,
           "method" => "call_tool",
           "params" => %{"name" => name, "arguments" => args}
         },
         state
       ) do
    case name do
      "cars.search_listings" ->
        {:ok, job} = Cars.enqueue_search(args)
        reply(id, %{mode: :job, job_id: job.id, status: job.status}, state)

      "cars.decode_vin" ->
        {:ok, job} = Cars.enqueue_decode_vin(args)
        reply(id, %{mode: :job, job_id: job.id, status: job.status}, state)

      "email.draft_haggle" ->
        reply(id, %{mode: :inline, result: Email.draft_haggle(args)}, state)

      "jobs.get" ->
        reply(id, handle_jobs_get(args), state)

      "jobs.cancel" ->
        reply(id, handle_jobs_cancel(args), state)

      _ ->
        reply(id, %{error: "unknown tool"}, state)
    end
  end

  defp process_request(%{"id" => id, "method" => _unknown}, state) do
    reply(id, %{error: "unknown method"}, state)
  end

  defp process_request(_other, state), do: {:noreply, state}

  defp handle_jobs_get(args) do
    case Jobs.get(args) do
      {:ok, job} -> %{mode: :inline, job: job}
      {:error, reason} -> %{error: reason}
    end
  end

  defp handle_jobs_cancel(args) do
    case Jobs.cancel(args) do
      {:ok, job} -> %{mode: :inline, job: job}
      {:error, reason} -> %{error: reason}
    end
  end

  defp tool_descriptor(%{name: name, mode: mode}) do
    %{name: name, execution: mode}
  end

  defp reply(id, result, %{port: port} = state) do
    envelope = %{id: id, result: result}

    case Jason.encode(envelope) do
      {:ok, json} -> Port.command(port, json <> "\n")
      _ -> :ok
    end

    {:noreply, state}
  end
end
