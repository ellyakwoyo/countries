defmodule Countries.Store.Config do
  @moduledoc """
  How a project's country table is reached and which of its columns the library writes.

  ## Options

    * `:repo` (required) - how the adapter reaches the database: an `Ecto.Repo` for
      the built-in adapters, or whatever a custom adapter expects.
    * `:schema` (required) - the project's Ecto schema for the table. It needs no
      Ecto repo, so it describes non-SQL collections too.
    * `:key` - the unique field records are matched on. Defaults to `:alpha_3`; a
      unique index on it is advised.
    * `:only` - keep only these columns up to date.
    * `:except` - never update these columns. Use it for columns the project edits
      itself.
    * `:adapter` - a `Countries.Adapter`. Picked from an Ecto repo when left out.

  A row the table lacks is inserted with every dataset column the schema has. Of
  those, the `owned` ones, narrowed by `:only` and `:except`, are kept up to date on
  existing rows. Columns the dataset lacks are never written.
  """

  alias Countries.{Adapter, Country}

  @enforce_keys [:repo, :schema, :key, :adapter, :columns, :owned]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          repo: Ecto.Repo.t(),
          schema: module(),
          key: atom(),
          adapter: module(),
          columns: [atom()],
          owned: [atom()]
        }

  @doc """
  Builds a config from the options above.

  Raises `ArgumentError` for an unknown option, a missing `:repo` or `:schema`, or a
  `:key` that is not a column both the dataset and the schema have.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    opts = Keyword.validate!(opts, [:repo, :schema, :adapter, :only, key: :alpha_3, except: []])
    repo = Keyword.get(opts, :repo) || raise ArgumentError, "missing required option :repo"
    schema = Keyword.get(opts, :schema) || raise ArgumentError, "missing required option :schema"
    key = Keyword.fetch!(opts, :key)
    columns = shared_columns(schema)

    %__MODULE__{
      repo: repo,
      schema: schema,
      key: ensure_key!(key, columns),
      adapter: Keyword.get(opts, :adapter) || Adapter.for_repo(repo),
      columns: columns,
      owned: Enum.uniq([key | owned(columns, opts[:only], opts[:except])])
    }
  end

  defp shared_columns(schema) do
    dataset = Keyword.keys(Country.columns())
    Enum.filter(schema.__schema__(:fields), &(&1 in dataset))
  end

  defp owned(columns, nil, except), do: columns -- except
  defp owned(columns, only, except), do: Enum.filter(columns, &(&1 in only)) -- except

  defp ensure_key!(key, columns) do
    if key in columns,
      do: key,
      else: raise(ArgumentError, "key #{inspect(key)} must be a dataset column the schema has")
  end
end
