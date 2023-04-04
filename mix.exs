defmodule KinoExplorer.MixProject do
  use Mix.Project

  @version "0.1.3"
  @description "Explorer integration with Livebook"

  def project do
    [
      app: :kino_explorer,
      version: @version,
      description: @description,
      name: "KinoExplorer",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {KinoExplorer.Application, []}
    ]
  end

  defp deps do
    [
      {:kino, "~> 0.8.1 or ~> 0.9.0"},
      {:explorer, "~> 0.5.5 or ~> 0.6.0"},
      {:rustler, "~> 0.27.0", optional: true},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "components",
      source_url: "https://github.com/livebook-dev/kino_explorer",
      source_ref: "v#{@version}",
      extras: ["guides/components.livemd"],
      groups_for_modules: [
        Kinos: [
          Kino.Explorer
        ]
      ]
    ]
  end

  def package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/livebook-dev/kino_explorer"
      }
    ]
  end
end
