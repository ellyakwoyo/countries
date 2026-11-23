defmodule Countries.Adapters.SQLite3 do
  @moduledoc """
  `Countries.Adapter` for SQLite, through `ecto_sqlite3`.

  Array columns are stored as JSON text, which `ecto_sqlite3` encodes and decodes.
  SQLite's `LIKE` ignores case for ASCII letters only, and has no escape character
  unless one is named, so searches name it.
  """

  use Countries.Adapters.Ecto, max_parameters: 32_766

  @impl Countries.Adapters.Ecto
  def search_query(queryable, pattern) do
    where(queryable, [c], fragment("? LIKE ? ESCAPE '\\'", c.name, ^pattern))
  end
end
