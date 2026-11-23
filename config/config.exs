import Config

if config_env() == :test do
  config :countries, Countries.Test.SQLiteRepo,
    database: Path.expand("../tmp/countries_test.db", __DIR__),
    pool: Ecto.Adapters.SQL.Sandbox

  config :countries, Countries.Test.PostgresRepo,
    username: System.get_env("DATABASE_USER", "postgres"),
    password: System.get_env("DATABASE_PASSWORD", "postgres"),
    hostname: System.get_env("DATABASE_HOST", "localhost"),
    port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
    database: "countries_test",
    pool: Ecto.Adapters.SQL.Sandbox

  config :logger, level: :warning
end
