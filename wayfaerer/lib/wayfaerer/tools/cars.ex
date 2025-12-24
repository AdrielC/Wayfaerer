defmodule Wayfaerer.Tools.Cars do
  @moduledoc """
  Car-related tools. Network operations are executed as jobs via the queue.
  """

  alias Wayfaerer.Jobs.JobQueue
  alias Wayfaerer.Providers.{ListingsProvider, NhtsaVinProvider}

  def enqueue_search(args), do: JobQueue.enqueue("cars.search_listings", args)
  def enqueue_decode_vin(args), do: JobQueue.enqueue("cars.decode_vin", args)

  def search_listings_job(args) do
    normalized = normalize_search(args)
    ListingsProvider.search(normalized)
  end

  def decode_vin_job(%{"vin" => vin}), do: decode_vin_job(%{vin: vin})

  def decode_vin_job(%{vin: vin}) when is_binary(vin) do
    vin |> String.trim() |> NhtsaVinProvider.decode_vin()
  end

  def decode_vin_job(_), do: raise(ArgumentError, "vin is required")

  defp normalize_search(args) when is_map(args) do
    %{
      make: Map.get(args, "make") || Map.get(args, :make),
      model: Map.get(args, "model") || Map.get(args, :model),
      max_price: Map.get(args, "max_price") || Map.get(args, :max_price)
    }
  end

  defp normalize_search(_), do: %{}
end
