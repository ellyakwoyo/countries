for {engine, repo} <- [SQLite: Countries.Test.SQLiteRepo, Postgres: Countries.Test.PostgresRepo] do
  defmodule Module.concat([Countries.Test, engine, Store]) do
    @moduledoc false
    use Countries.Store, repo: repo, schema: Countries.Test.Country
  end

  defmodule Module.concat([Countries.Test, engine, IntegerStore]) do
    @moduledoc false
    use Countries.Store, repo: repo, schema: Countries.Test.IntegerCountry
  end

  defmodule Module.concat([Countries.Test, engine, LegacyStore]) do
    @moduledoc false
    use Countries.Store,
      repo: repo,
      schema: Countries.Test.LegacyCountry,
      key: :code,
      except: [:is_frequently_selected]
  end
end

defmodule Countries.Test.MemoryStore do
  @moduledoc false
  use Countries.Store,
    repo: Countries.Test.MemoryAdapter,
    schema: Countries.Test.Country,
    adapter: Countries.Test.MemoryAdapter
end
