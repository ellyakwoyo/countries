defmodule Countries.Adapter do
  @moduledoc """
  How `Countries.Store` reads and writes a project's country table on one database.

  The store works out what to change; the adapter only runs the reads and writes, so
  any database fits, SQL or not. Records are described by the project's Ecto schema
  (`Ecto.Schema` works without an Ecto repo), which gives the field names and types.

  ## Built-in adapters

  An Ecto repo is matched to its adapter automatically:

  | Ecto adapter             | Countries adapter             |
  | ------------------------ | ----------------------------- |
  | `Ecto.Adapters.Postgres` | `Countries.Adapters.Postgres` |
  | `Ecto.Adapters.SQLite3`  | `Countries.Adapters.SQLite3`  |
  | `Ecto.Adapters.MyXQL`    | `Countries.Adapters.MySQL`    |

  For anything else, such as MongoDB, implement this behaviour and pass `adapter:` to
  `use Countries.Store`. The store's `:repo` option is handed over untouched, so it
  can be whatever the adapter needs to reach the database: a connection name, a pid or
  a module. The "Adapters" guide in the README walks through one.
  """

  alias Countries.Store.Config

  @typedoc "A map of field name to value, holding the fields a call asks for."
  @type row :: %{atom() => term()}

  @doc "Every record, as schema structs ordered by name."
  @callback all(Config.t()) :: [struct()]

  @doc "The record with the given primary key, or `nil`."
  @callback get(Config.t(), id :: term()) :: struct() | nil

  @doc "The record whose `field` equals `value`, or `nil`."
  @callback get_by(Config.t(), field :: atom(), value :: term()) :: struct() | nil

  @doc """
  Records whose name contains `term`, ignoring case, ordered by name.

  Characters with a special meaning to the database's pattern syntax must match only
  themselves.
  """
  @callback search(Config.t(), term :: String.t()) :: [struct()]

  @doc "Every record, as rows holding only the config's `owned` fields."
  @callback load(Config.t()) :: [row()]

  @doc """
  Inserts `inserts` and applies `updates`, each a `{key_value, changes}` pair matched
  on the config's `key`, all or nothing.

  Inserted rows hold no primary key unless the schema generates one in Elixir
  (`:binary_id`); otherwise the database assigns it.
  """
  @callback write(Config.t(), inserts :: [row()], updates :: [{term(), row()}]) ::
              :ok | {:error, term()}

  @adapters %{
    Ecto.Adapters.Postgres => Countries.Adapters.Postgres,
    Ecto.Adapters.SQLite3 => Countries.Adapters.SQLite3,
    Ecto.Adapters.MyXQL => Countries.Adapters.MySQL
  }

  @doc """
  The built-in adapter for an Ecto `repo`.

  Raises `ArgumentError` for anything without one; pass `adapter:` then.
  """
  @spec for_repo(term()) :: module()
  def for_repo(repo) do
    ecto_adapter = ecto_adapter(repo)

    @adapters
    |> Map.fetch(ecto_adapter)
    |> supported!(repo, ecto_adapter)
  end

  defp ecto_adapter(repo) when is_atom(repo) do
    if Code.ensure_loaded?(repo) and function_exported?(repo, :__adapter__, 0),
      do: repo.__adapter__()
  end

  defp ecto_adapter(_repo), do: nil

  defp supported!({:ok, adapter}, _repo, _ecto_adapter), do: adapter

  defp supported!(:error, repo, ecto_adapter) do
    raise ArgumentError,
          "no built-in Countries adapter for #{inspect(repo)} " <>
            "(Ecto adapter: #{inspect(ecto_adapter)}); " <>
            "pass `adapter:` with a module implementing #{inspect(__MODULE__)}"
  end
end
