defmodule Countries.Test.SQLiteRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :countries, adapter: Ecto.Adapters.SQLite3
end

defmodule Countries.Test.PostgresRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :countries, adapter: Ecto.Adapters.Postgres
end
