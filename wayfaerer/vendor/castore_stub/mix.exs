defmodule CastoreStub.MixProject do
  use Mix.Project

  def project do
    [
      app: :castore,
      version: "0.0.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:logger, :public_key],
      mod: {CastoreStub.Application, []}
    ]
  end
end
