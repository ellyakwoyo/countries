defmodule Countries.Store do
  @moduledoc """
  Keeps a project's own country table in step with the dataset, and reads from it.

  The project keeps its table, schema, primary keys and foreign keys. The library only
  writes the fields it owns (see `Countries.Store.Config`) and never deletes a record.

      defmodule MyApp.Countries.Store do
        use Countries.Store,
          repo: MyApp.Repo,
          schema: MyApp.Countries.Country,
          key: :code
      end

  A project with several databases defines one store for each. The database is
  reached through a `Countries.Adapter`, picked from the repo or passed as `adapter:`.

  ## Generated functions

    * `all/0`, `get/1`, `resolve/1`, `search/1` - read the table.
    * `diff/1` - returns a `Countries.Store.Plan` without writing anything.
    * `sync/1` - applies the plan, all or nothing.

  Nothing is written until `sync/1` is called, so a project can use the store's reads,
  or `Countries` directly, while its table stays exactly as it is.

  `diff/1` and `sync/1` accept the `:only` and `:except` options of
  `Countries.Store.Config` to override the store's for one call. `sync/1` also takes
  `:mode`: `:upsert` (the default) inserts missing records and updates changed ones,
  while `:insert` only inserts missing records.

  Every generated function is overridable. The functions below take a
  `Countries.Store.Config` and can be called directly instead.
  """

  alias Countries.Country
  alias Countries.Store.{Config, Plan}

  @type mode :: :upsert | :insert
  @type result :: %{inserted: non_neg_integer(), updated: non_neg_integer()}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Countries.Store

      @countries_store_opts opts

      @doc false
      @spec __countries_config__(keyword()) :: Store.Config.t()
      def __countries_config__(overrides \\ []) do
        Store.Config.new(Keyword.merge(@countries_store_opts, overrides))
      end

      @doc "Every record in the table, ordered by name."
      def all, do: Store.all(__countries_config__())

      @doc "The record with the given primary key, or `nil`."
      def get(id), do: Store.get(__countries_config__(), id)

      @doc "The record for a free-text country value, or `nil`. See `Countries.resolve/1`."
      def resolve(value), do: Store.resolve(__countries_config__(), value)

      @doc "Records whose name contains `term`, ignoring case, ordered by name."
      def search(term), do: Store.search(__countries_config__(), term)

      @doc "What `sync/1` would change. See `Countries.Store.Plan`."
      def diff(opts \\ []), do: Store.diff(__countries_config__(opts))

      @doc "Writes the dataset to the table. See `Countries.Store`."
      def sync(opts \\ []) do
        {mode, overrides} = Keyword.pop(opts, :mode, :upsert)
        Store.sync(__countries_config__(overrides), mode)
      end

      defoverridable all: 0, get: 1, resolve: 1, search: 1, diff: 0, diff: 1, sync: 0, sync: 1
    end
  end

  @doc """
  Every record in the table, ordered by name.
  """
  @spec all(Config.t()) :: [struct()]
  def all(%Config{adapter: adapter} = config), do: adapter.all(config)

  @doc """
  The record with the given primary key, or `nil`.
  """
  @spec get(Config.t(), term()) :: struct() | nil
  def get(%Config{adapter: adapter} = config, id), do: adapter.get(config, id)

  @doc """
  The record for a free-text country value, or `nil`.

  The value is resolved against the dataset with `Countries.resolve/1`, then the record
  is fetched by the store's key, so it behaves the same on every database.
  """
  @spec resolve(Config.t(), String.t() | nil) :: struct() | nil
  def resolve(%Config{} = config, value) do
    value
    |> Countries.resolve()
    |> fetch_by_key(config)
  end

  @doc """
  Records whose name contains `term`, ignoring case, ordered by name.

  Wildcards in `term` match only themselves.
  """
  @spec search(Config.t(), String.t()) :: [struct()]
  def search(%Config{adapter: adapter} = config, term) when is_binary(term) do
    adapter.search(config, term)
  end

  @doc """
  Compares the table with the dataset without writing anything.
  """
  @spec diff(Config.t()) :: Plan.t()
  def diff(%Config{adapter: adapter} = config) do
    Plan.build(desired_rows(config), adapter.load(config), config.key)
  end

  @doc """
  Writes the dataset to the table, all or nothing.

  Returns `{:error, reason}` when the adapter reports a failed write.
  """
  @spec sync(Config.t(), mode()) :: {:ok, result()} | {:error, term()}
  def sync(%Config{adapter: adapter} = config, mode \\ :upsert) when mode in [:upsert, :insert] do
    plan = diff(config)
    inserts = stamp(plan.insert, config.schema, :autogenerate)
    updates = updates(config.schema, plan, mode)

    config
    |> adapter.write(inserts, updates)
    |> synced(%{inserted: length(inserts), updated: length(updates)})
  end

  defp fetch_by_key(nil, _config), do: nil

  defp fetch_by_key(%Country{} = country, %Config{adapter: adapter, key: key} = config) do
    adapter.get_by(config, key, Map.fetch!(country, key))
  end

  defp desired_rows(%Config{schema: schema, columns: columns}) do
    Enum.map(Countries.all(), fn country ->
      country
      |> Country.attributes()
      |> Map.take(columns)
      |> Map.new(fn {column, value} -> {column, cast!(schema, column, value)} end)
    end)
  end

  defp cast!(schema, field, value) do
    :type
    |> schema.__schema__(field)
    |> Ecto.Type.cast(value)
    |> cast_result!(schema, field, value)
  end

  defp cast_result!({:ok, cast}, _schema, _field, _value), do: cast

  defp cast_result!(_error, schema, field, value) do
    raise ArgumentError,
          "cannot cast #{inspect(value)} for #{inspect(schema)}.#{field}; " <>
            "add #{inspect(field)} to the store's :except option"
  end

  defp updates(_schema, %Plan{}, :insert), do: []

  defp updates(schema, %Plan{update: updates}, :upsert) do
    Enum.map(updates, fn %{key: key, changes: changes} ->
      values = Map.new(changes, fn {field, {_current, value}} -> {field, value} end)
      {key, [values] |> stamp(schema, :autoupdate) |> hd()}
    end)
  end

  defp stamp(rows, schema, kind) do
    timestamps =
      for {fields, {module, function, args}} <- schema.__schema__(kind),
          value <- [apply(module, function, args)],
          field <- fields,
          into: %{},
          do: {field, value}

    Enum.map(rows, &Map.merge(&1, timestamps))
  end

  defp synced(:ok, result), do: {:ok, result}
  defp synced({:error, reason}, _result), do: {:error, reason}
end
