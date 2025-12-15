defmodule Wayfaerer.Providers.NhtsaVinProvider do
  @moduledoc """
  Real VIN decoder backed by the NHTSA vPIC API.
  """

  @endpoint "https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvalues"

  def decode_vin(vin) when is_binary(vin) do
    url = "#{@endpoint}/#{URI.encode(vin)}?format=json"
    request = Finch.build(:get, url)

    with {:ok, %Finch.Response{status: 200, body: body}} <-
           Finch.request(request, Wayfaerer.Finch),
         {:ok, decoded} <- Jason.decode(body),
         %{"Results" => [result | _]} <- decoded do
      {:ok, simplify_result(result)}
    else
      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :unexpected_response}
    end
  end

  defp simplify_result(result) do
    %{
      make: result["Make"],
      model: result["Model"],
      model_year: result["ModelYear"],
      body_class: result["BodyClass"],
      vin: result["VIN"] || result["VIN"],
      decoded_at: System.system_time(:millisecond)
    }
  end
end
