defmodule Countries.Adapters.Postgres do
  @moduledoc """
  `Countries.Adapter` for PostgreSQL, through `postgrex`.

  Array columns are native `text[]`. Searches use `ILIKE`, which ignores case for
  every alphabet.
  """

  use Countries.Adapters.Ecto, max_parameters: 65_535

  @impl Countries.Adapters.Ecto
  def search_query(queryable, pattern), do: where(queryable, [c], ilike(c.name, ^pattern))
end
