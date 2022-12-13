defmodule KinoExplorer.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_explorer,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {KinoExplorer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:kino, "~> 0.8"},
      {:explorer, "~> 0.5.0-dev", github: "elixir-nx/explorer"},
      {:rustler, "~> 0.26.0", optional: true},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
