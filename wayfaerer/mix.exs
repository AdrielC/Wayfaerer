defmodule Wayfaerer.MixProject do
  use Mix.Project

  def project do
    [
      app: :wayfaerer,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Wayfaerer.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:finch, "~> 0.17"}
    ]
  end
end
