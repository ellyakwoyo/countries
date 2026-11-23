defmodule Countries.Test.Setup do
  @moduledoc false

  alias Countries.Test.{PostgresRepo, SQLiteRepo}
  alias Ecto.Adapters.SQL.Sandbox

  @engines [
    %{repo: SQLiteRepo, stores: Countries.Test.SQLite},
    %{repo: PostgresRepo, stores: Countries.Test.Postgres}
  ]

  @doc "Recreates, migrates and starts each engine's repo, keeping the reachable ones."
  @spec prepare!() :: :ok
  def prepare! do
    reachable = Enum.filter(@engines, &prepare(&1.repo))
    Enum.each(@engines -- reachable, &IO.puts("Skipping #{inspect(&1.repo)}: unreachable"))
    Application.put_env(:countries, :test_engines, reachable)
  end

  @doc "The engines `prepare!/0` reached, as `ExUnit.Case` parameters."
  @spec engines() :: [map()]
  def engines, do: Application.fetch_env!(:countries, :test_engines)

  defp prepare(repo) do
    config = repo.config()
    adapter = repo.__adapter__()
    adapter.storage_down(config)

    config
    |> adapter.storage_up()
    |> start(repo)
  end

  defp start({:error, _reason}, _repo), do: false

  defp start(:ok, repo) do
    {:ok, _pid} = repo.start_link()
    Sandbox.mode(repo, :auto)
    Ecto.Migrator.up(repo, 1, Countries.Test.Migration, log: false)
    Sandbox.mode(repo, :manual)
    true
  end
end
