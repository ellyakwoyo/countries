defmodule Countries.Adapters.MySQL do
  @moduledoc """
  `Countries.Adapter` for MySQL and MariaDB, through `myxql`.

  MySQL has no array type, so use `arrays: :json` in `Countries.Schema` and
  `Countries.Migration` to store list fields as JSON text. `LIKE` ignores case under
  the default `_ci` collations and escapes with a backslash.
  """

  use Countries.Adapters.Ecto, max_parameters: 65_535

  @impl Countries.Adapters.Ecto
  def search_query(queryable, pattern) do
    where(queryable, [c], fragment("? LIKE ?", c.name, ^pattern))
  end
end
