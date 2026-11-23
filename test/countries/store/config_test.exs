defmodule Countries.Store.ConfigTest do
  use ExUnit.Case, async: true

  alias Countries.Store.Config
  alias Countries.Test.{LegacyCountry, MemoryAdapter, PostgresRepo, SQLiteRepo}

  defmodule MySQLRepo do
    def __adapter__, do: Ecto.Adapters.MyXQL
  end

  defmodule UnknownRepo do
    def __adapter__, do: Ecto.Adapters.Unknown
  end

  defp new(opts), do: Config.new(Keyword.merge([repo: SQLiteRepo, schema: LegacyCountry], opts))

  test "writes the dataset columns the schema has, and nothing else" do
    config = new(key: :code)

    expected = [
      :name,
      :code,
      :alpha_3,
      :unicode,
      :is_country,
      :iso_codes,
      :is_frequently_selected
    ]

    assert Enum.sort(config.columns) == Enum.sort(expected)
    assert Enum.sort(config.owned) == Enum.sort(expected)
  end

  test "narrows the owned columns with :only and :except, keeping the key" do
    assert new(key: :code, only: [:name]).owned == [:code, :name]

    config = new(except: [:unicode])

    refute :unicode in config.owned
    assert :unicode in config.columns
  end

  test "picks the adapter from an Ecto repo" do
    assert new([]).adapter == Countries.Adapters.SQLite3
    assert new(repo: PostgresRepo).adapter == Countries.Adapters.Postgres
    assert new(repo: MySQLRepo).adapter == Countries.Adapters.MySQL
  end

  test "takes any repo with an explicit adapter" do
    assert new(repo: :mongo, adapter: MemoryAdapter).adapter == MemoryAdapter
    assert new(repo: UnknownRepo, adapter: MemoryAdapter).repo == UnknownRepo
  end

  test "rejects bad options" do
    assert_raise ArgumentError, ~r/no built-in Countries adapter/, fn ->
      new(repo: UnknownRepo)
    end

    assert_raise ArgumentError, ~r/no built-in Countries adapter/, fn -> new(repo: :mongo) end
    assert_raise ArgumentError, ~r/key :verified/, fn -> new(key: :verified) end
    assert_raise ArgumentError, ~r/:schema/, fn -> Config.new(repo: SQLiteRepo) end
    assert_raise ArgumentError, ~r/unknown keys/, fn -> new(table: "countries") end
  end
end
