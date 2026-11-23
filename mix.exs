defmodule Countries.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :countries,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      name: "Countries",
      description: "Shared country reference data, with Ecto sync for PostgreSQL and SQLite.",
      docs: docs(),
      dialyzer: [plt_add_apps: [:ecto_sql]]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:jason, "~> 1.4"},
      {:postgrex, ">= 0.0.0", only: :test},
      {:ecto_sqlite3, "~> 0.25", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [lint: ["format --check-formatted", "credo --strict", "dialyzer"]]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Data: [Countries, Countries.Country, Countries.Dataset, Countries.Lookup],
        Database: [Countries.Store, Countries.Store.Config, Countries.Store.Plan],
        Adapters: [
          Countries.Adapter,
          Countries.Adapters.Ecto,
          Countries.Adapters.Postgres,
          Countries.Adapters.SQLite3,
          Countries.Adapters.MySQL
        ],
        "New projects": [Countries.Schema, Countries.Migration, Countries.Types.JSONList]
      ]
    ]
  end
end
