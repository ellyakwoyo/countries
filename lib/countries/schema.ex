defmodule Countries.Schema do
  @moduledoc """
  Sets up a new project's Ecto schema for its country table.

      defmodule MyApp.Countries.Country do
        use Countries.Schema

        schema "countries" do
          country_fields()

          field :verified, :boolean, default: true

          timestamps(type: :utc_datetime)
        end
      end

  ## Options

    * `:primary_key` - `:uuid` (the default) for a `:binary_id` key generated in
      Elixir, or `:integer` for one the database assigns. Foreign keys declared in the
      schema follow the same type.
    * `:arrays` - `:native` (the default) for engines with an array type, such as
      PostgreSQL and SQLite, or `:json` to store list fields as JSON text, for MySQL
      for example.

  Use the same options in `Countries.Migration.create_table/2`. Existing projects keep
  their own schemas: `Countries.Store` syncs whichever dataset fields a schema has.
  """

  alias Countries.Country

  @type primary_key :: :uuid | :integer
  @type arrays :: :native | :json

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Ecto.Schema
      import Countries.Schema, only: [country_fields: 0]

      opts = Keyword.validate!(opts, primary_key: :uuid, arrays: :native)
      {primary_key, foreign_key_type} = Countries.Schema.__keys__(opts[:primary_key])

      @primary_key primary_key
      @foreign_key_type foreign_key_type
      @countries_fields Countries.Schema.__fields__(opts[:arrays])
    end
  end

  @doc """
  Defines a field for each of `Countries.Country.columns/0`. Call it inside `schema/2`.
  """
  defmacro country_fields do
    quote do
      for {name, type, opts} <- @countries_fields, do: field(name, type, opts)
    end
  end

  @doc false
  @spec __keys__(primary_key()) :: {tuple(), atom()}
  def __keys__(:uuid), do: {{:id, :binary_id, autogenerate: true}, :binary_id}
  def __keys__(:integer), do: {{:id, :id, autogenerate: true}, :id}

  def __keys__(other) do
    raise ArgumentError, ":primary_key must be :uuid or :integer, got: #{inspect(other)}"
  end

  @doc false
  @spec __fields__(arrays()) :: [{atom(), Ecto.Type.t(), keyword()}]
  def __fields__(arrays) do
    for {name, {type, opts}} <- Country.columns(),
        do: {name, field_type(type, arrays), Keyword.take(opts, [:default])}
  end

  defp field_type({:array, :string}, :native), do: {:array, :string}
  defp field_type({:array, :string}, :json), do: Countries.Types.JSONList
  defp field_type({:array, :string}, other), do: raise_arrays!(other)
  defp field_type(type, _arrays), do: type

  @doc false
  @spec raise_arrays!(term()) :: no_return()
  def raise_arrays!(other) do
    raise ArgumentError, ":arrays must be :native or :json, got: #{inspect(other)}"
  end
end
