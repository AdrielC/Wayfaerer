defmodule Wayfaerer.Tools.Email do
  @moduledoc """
  Inline-only email drafting utilities.
  """

  def draft_haggle(args) when is_map(args) do
    name = Map.get(args, "name") || Map.get(args, :name) || "there"
    listing = Map.get(args, "listing") || Map.get(args, :listing) || "the vehicle"
    target_price = Map.get(args, "target_price") || Map.get(args, :target_price)

    price_sentence =
      case target_price do
        nil -> "I'm looking for your best out-the-door price."
        price -> "I can sign quickly at #{price} if the vehicle matches the listing."
      end

    [
      "Hi #{name},",
      "",
      "I saw #{listing} and wanted to discuss pricing.",
      price_sentence,
      "",
      "I'm ready to move fast if we can keep the process simple.",
      "",
      "Thanks,",
      "A motivated buyer"
    ]
    |> Enum.join("\n")
  end
end
