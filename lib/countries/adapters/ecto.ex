defmodule Countries.Adapters.Ecto do
  @moduledoc """
  The `Countries.Adapter` implementation shared by every Ecto SQL engine.

  An engine module only supplies what differs between engines:

      defmodule Countries.Adapters.Postgres do
        use Countries.Adapters.Ecto, max_parameters: 65_535

        @impl Countries.Adapters.Ecto
        def search_query(queryable, pattern), do: where(queryable, [c], ilike(c.name, ^pattern))
      end

  Writes use plain inserts and per-row updates, so no engine needs upsert support or
  a unique index on the store's key, though one is still advised.
  """

  import Ecto.Query

  alias Countries.Store.Config

  @doc """
  Narrows `queryable` to rows whose `name` contains `pattern`, ignoring case.

  `pattern` is a `LIKE` pattern wrapped in `%`, in which `\\`, `%`, `_` and `[` are
  escaped with a backslash.
  """
  @callback search_query(Ecto.Queryable.t(), pattern :: String.t()) :: Ecto.Query.t()

  defmacro __using__(opts) do
    max_parameters = Keyword.fetch!(opts, :max_parameters)

    quote do
      @behaviour Countries.Adapter
      @behaviour Countries.Adapters.Ecto

      import Ecto.Query

      alias Countries.Adapters.Ecto, as: Base

      @impl Countries.Adapter
      def all(config), do: Base.all(config)

      @impl Countries.Adapter
      def get(config, id), do: Base.get(config, id)

      @impl Countries.Adapter
      def get_by(config, field, value), do: Base.get_by(config, field, value)

      @impl Countries.Adapter
      def search(config, term), do: Base.search(__MODULE__, config, term)

      @impl Countries.Adapter
      def load(config), do: Base.load(config)

      @impl Countries.Adapter
      def write(config, inserts, updates) do
        Base.write(config, inserts, updates, unquote(max_parameters))
      end
    end
  end

  @doc false
  @spec all(Config.t()) :: [struct()]
  def all(%Config{repo: repo, schema: schema}), do: schema |> order_by(asc: :name) |> repo.all()

  @doc false
  @spec get(Config.t(), term()) :: struct() | nil
  def get(%Config{repo: repo, schema: schema}, id), do: repo.get(schema, id)

  @doc false
  @spec get_by(Config.t(), atom(), term()) :: struct() | nil
  def get_by(%Config{repo: repo, schema: schema}, field, value) do
    repo.get_by(schema, [{field, value}])
  end

  @doc false
  @spec search(module(), Config.t(), String.t()) :: [struct()]
  def search(engine, %Config{repo: repo, schema: schema}, term) do
    schema
    |> engine.search_query("%" <> escape_like(term) <> "%")
    |> order_by(asc: :name)
    |> repo.all()
  end

  @doc false
  @spec load(Config.t()) :: [Countries.Adapter.row()]
  def load(%Config{repo: repo, schema: schema, owned: owned}) do
    repo.all(from(row in schema, select: map(row, ^owned)))
  end

  @doc false
  @spec write(Config.t(), [map()], [{term(), map()}], pos_integer()) :: :ok | {:error, term()}
  def write(%Config{repo: repo} = config, inserts, updates, max_parameters) do
    per_statement = max(div(max_parameters, length(config.columns) + 3), 1)

    repo.transaction(fn ->
      inserts
      |> Enum.chunk_every(per_statement)
      |> Enum.each(&repo.insert_all(config.schema, &1))

      Enum.each(updates, &update!(config, &1))
    end)
    |> written()
  end

  defp update!(%Config{repo: repo, schema: schema, key: key}, {value, changes}) do
    schema
    |> where([row], field(row, ^key) == ^value)
    |> repo.update_all(set: Map.to_list(changes))
  end

  defp written({:ok, _result}), do: :ok
  defp written({:error, reason}), do: {:error, reason}

  defp escape_like(term), do: String.replace(term, ["\\", "%", "_", "["], &("\\" <> &1))
end
