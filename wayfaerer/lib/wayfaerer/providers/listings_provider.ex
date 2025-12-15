defmodule Wayfaerer.Providers.ListingsProvider do
  @moduledoc """
  Behaviour and dispatcher for vehicle listings providers.
  """

  @callback search(map()) :: list()

  def search(args) do
    provider().search(args)
  end

  defp provider do
    case System.get_env("LISTINGS_PROVIDER", "mock") do
      "mock" -> Wayfaerer.Providers.ListingsProvider.Mock
      other -> raise("Unknown listings provider: #{other}")
    end
  end
end

defmodule Wayfaerer.Providers.ListingsProvider.Mock do
  @behaviour Wayfaerer.Providers.ListingsProvider

  @inventory [
    %{id: "1", make: "Honda", model: "Civic", year: 2020, price: 19_500},
    %{id: "2", make: "Toyota", model: "Camry", year: 2021, price: 21_000},
    %{id: "3", make: "Subaru", model: "Outback", year: 2019, price: 17_200}
  ]

  @impl true
  def search(%{make: make, model: model, max_price: max_price}) do
    @inventory
    |> Enum.filter(&match_make(&1, make))
    |> Enum.filter(&match_model(&1, model))
    |> Enum.filter(&match_price(&1, max_price))
  end

  def search(_), do: @inventory

  defp match_make(listing, nil), do: true

  defp match_make(listing, make),
    do: String.downcase(listing.make) == String.downcase(to_string(make))

  defp match_model(listing, nil), do: true

  defp match_model(listing, model),
    do: String.downcase(listing.model) == String.downcase(to_string(model))

  defp match_price(listing, nil), do: true

  defp match_price(listing, max_price) when is_binary(max_price) do
    match_price(listing, String.to_integer(max_price))
  end

  defp match_price(listing, max_price) when is_number(max_price), do: listing.price <= max_price
end
