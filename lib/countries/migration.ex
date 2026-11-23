defmodule Countries.Migration do
  @moduledoc """
  Creates a new project's country table on any Ecto SQL engine.

      defmodule MyApp.Repo.Migrations.CreateCountries do
        use Ecto.Migration

        def change do
          Countries.Migration.create_table()
        end
      end

  `create_table/2` takes the same `:primary_key` and `:arrays` options as
  `Countries.Schema`, so the two always agree:

      Countries.Migration.create_table(:countries, primary_key: :integer, arrays: :json)

  For a table laid out by hand, call `columns/1` inside `create table/2` and then
  `indexes/1`.

  When a later release adds a column to the dataset, `Countries.Store` ignores it until
  the project's schema has it, so upgrading the library never requires a migration.
  """

  import Ecto.Migration

  alias Countries.{Country, Schema}

  @doc """
  Creates the table with a primary key, every dataset column, timestamps and indexes.

  ## Options

    * `:primary_key` - `:uuid` (the default) or `:integer`, auto-incremented by the
      database.
    * `:arrays` - `:native` (the default) or `:json`.
    * `:timestamps` - options for `Ecto.Migration.timestamps/1`. Defaults to
      `[type: :utc_datetime]`.
  """
  @spec create_table(atom(), keyword()) :: :ok
  def create_table(table \\ :countries, opts \\ []) do
    opts =
      Keyword.validate!(opts,
        primary_key: :uuid,
        arrays: :native,
        timestamps: [type: :utc_datetime]
      )

    create table(table, primary_key: primary_key(opts[:primary_key])) do
      columns(arrays: opts[:arrays])
      timestamps(opts[:timestamps])
    end

    indexes(table)
  end

  @doc """
  Adds every column of `Countries.Country.columns/0`. Call it inside `create table/2`.

  Takes the `:arrays` option of `create_table/2`.
  """
  @spec columns(keyword()) :: :ok
  def columns(opts \\ []) do
    arrays = opts |> Keyword.validate!(arrays: :native) |> Keyword.fetch!(:arrays)

    Enum.each(Country.columns(), fn {name, {type, column_opts}} ->
      add(name, column_type(type, arrays), column_opts(type, arrays, column_opts))
    end)
  end

  @doc """
  Creates unique indexes on `alpha_3` and `code`, and an index on `name`.
  """
  @spec indexes(atom()) :: :ok
  def indexes(table \\ :countries) do
    create unique_index(table, [:alpha_3])
    create unique_index(table, [:code])
    create index(table, [:name])
    :ok
  end

  defp primary_key(:uuid), do: [type: :binary_id]
  defp primary_key(:integer), do: true
  defp primary_key(other), do: Schema.__keys__(other)

  defp column_type({:array, :string}, :json), do: :text
  defp column_type({:array, :string}, :native), do: {:array, :string}
  defp column_type({:array, :string}, other), do: Schema.raise_arrays!(other)
  defp column_type(type, _arrays), do: type

  # Some engines (MySQL before 8.0.13) reject a default on a TEXT column.
  defp column_opts({:array, :string}, :json, opts), do: Keyword.delete(opts, :default)
  defp column_opts(_type, _arrays, opts), do: opts
end
