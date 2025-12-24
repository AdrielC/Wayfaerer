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
      extra_applications: [:logger, :crypto, :public_key],
      mod: {Wayfaerer.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, git: "https://github.com/michalmuskala/jason.git", tag: "v1.4.4"},
      {:finch, git: "https://github.com/sneako/finch.git", tag: "v0.17.0"},
      {:mint, git: "https://github.com/elixir-mint/mint.git", tag: "v1.7.1", override: true},
      {:hpax, git: "https://github.com/elixir-mint/hpax.git", tag: "v1.0.0", override: true},
      {:castore, path: "vendor/castore_stub", override: true},
      {:nimble_options, git: "https://github.com/dashbitco/nimble_options.git", tag: "v1.1.1", override: true},
      {:nimble_pool, git: "https://github.com/dashbitco/nimble_pool.git", tag: "v1.1.0", override: true},
      {:telemetry, git: "https://github.com/beam-telemetry/telemetry.git", tag: "v1.3.0", override: true},
      {:mime, git: "https://github.com/elixir-plug/mime.git", tag: "v2.0.6", override: true}
    ]
  end
end
