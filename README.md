# Countries

Country reference data for Elixir applications, kept in one place.

The dataset ships inside the library. Applications read it directly, or sync it into
their own database table. When a country changes, the change is made once here and
released. Every application picks it up by upgrading the dependency.

- **No setup for reads.** The dataset is compiled in, so lookups need no database or
  process.
- **Free-text lookup.** Codes, names, former names, nationalities and passport-scanner
  spellings resolve to a country, ignoring case, accents and punctuation.
- **Safe for existing tables.** A sync writes only the columns the application's
  schema shares with the dataset, previews changes first, and never deletes a row.
- **Any database.** PostgreSQL, SQLite and MySQL are built in, and other databases,
  SQL or not, plug in through an adapter.
- **Flexible primary keys.** New tables use UUIDs by default, or auto-incremented
  integers.

## Installation

Add `countries` to your dependencies:

```elixir
def deps do
  [
    {:countries, git: "<repository url>", tag: "v0.1.0"}
  ]
end
```

Your application supplies its own database driver, such as `postgrex`,
`ecto_sqlite3` or `myxql`.

## Reading the dataset

```elixir
Countries.get("KEN")
#=> %Countries.Country{alpha_3: "KEN", code: "KE", name: "Kenya", dial_code: "+254", ...}

Countries.fetch("ZZZ")
#=> :error

Countries.where(is_country: true, dial_code: "+254")
#=> [%Countries.Country{alpha_3: "KEN", ...}]

Countries.resolve("côte d'ivoire")    #=> %Countries.Country{alpha_3: "CIV", ...}
Countries.resolve("Kenyan")           #=> %Countries.Country{alpha_3: "KEN", ...}
Countries.resolve("BRITISH CITIZEN")  #=> %Countries.Country{alpha_3: "GBR", ...}
Countries.resolve("Atlantis")         #=> nil
```

When a value matches several countries, the stronger match wins. An alpha-3 code beats
a two-letter code, which beats another ISO code, which beats a name or alias. A
sovereign country beats a territory.

## The dataset

The dataset holds 263 entries: sovereign countries, territories (`is_country: false`),
legacy codes such as `D` for Germany, and travel-document codes such as `XXA` for
stateless persons. Each entry is a `Countries.Country` with:

| Group          | Fields |
| -------------- | ------ |
| Identity       | `alpha_3`, `code`, `iso_codes`, `name`, `display_code` |
| Display        | `dial_code`, `image`, `unicode` (flag code points) |
| Classification | `is_country`, `is_issuer`, `is_3a`, `is_common_wealth`, `is_gratis`, `is_high_risk`, `is_frequently_selected`, `participation_type` |
| Exemptions     | `is_exempt`, `days_exempt`, `is_diplomatic_exempt`, `is_service_exempt`, `is_special_exempt` and their `*_days` |
| Lookup         | `aliases`, `nationalities`, `scanner_aliases`, `notes` |

Two more columns are derived for database tables: `lookup_values` and
`normalized_lookup_values`.

## Syncing a database table

Define a store for the table, naming your repo and your existing Ecto schema:

```elixir
defmodule MyApp.Countries.Countries do
  use Countries.Store,
    repo: MyApp.Repo,
    schema: MyApp.Countries.Country
end
```

| Option    | Description | Default |
| --------- | ----------- | ------- |
| `repo`    | How the adapter reaches the database. For the built-in adapters, an `Ecto.Repo`. | required |
| `schema`  | The Ecto schema for the table. Only the dataset fields it has are written. | required |
| `key`     | The unique field rows are matched on, such as `:alpha_3` or `:code`. | `:alpha_3` |
| `only`    | Keep only these fields up to date. | all shared fields |
| `except`  | Fill these fields when a row is inserted, but never update them. | `[]` |
| `adapter` | A `Countries.Adapter` module. | picked from the repo |

The store module gets:

| Function    | Description |
| ----------- | ----------- |
| `all/0`     | Every row, ordered by name. |
| `get/1`     | The row with the given primary key. |
| `resolve/1` | The row for a free-text value, as in `Countries.resolve/1`. |
| `search/1`  | Rows whose name contains a term, ignoring case. |
| `diff/1`    | What a sync would change, without writing anything. |
| `sync/1`    | Writes the changes, all or nothing. |

An application with several databases defines one store per database.

### Adding the library to an existing table

Nothing is written until you call `sync/0`. Reads and diffs never change the table,
so an application can depend on the library without its data being touched.

1. **Preview the changes.**

   ```elixir
   iex> plan = MyApp.Countries.Store.diff()
   iex> plan.insert   # rows the table lacks
   iex> plan.update   # [%{key: "TZA", changes: %{name: {"Tanzania", "United Republic of Tanzania"}}}]
   iex> plan.unknown  # keys only the table has; they are never deleted
   ```

2. **Protect the fields your application manages.** List them in `except:`.
   Columns the dataset doesn't have are never written in any case.

3. **Sync.**

   ```elixir
   MyApp.Countries.Store.sync()
   #=> {:ok, %{inserted: 2, updated: 57}}

   MyApp.Countries.Store.sync(mode: :insert)    # add missing rows only
   MyApp.Countries.Store.sync(except: [:name])  # override options for one call
   ```

A sync updates only the rows that changed, so `updated_at` keeps its meaning. Call
it from seeds, a release task, or application start-up.

## Creating a new table

Use the migration and schema helpers, which always agree with each other:

```elixir
defmodule MyApp.Repo.Migrations.CreateCountries do
  use Ecto.Migration

  def change do
    Countries.Migration.create_table()
  end
end
```

```elixir
defmodule MyApp.Countries.Country do
  use Countries.Schema

  schema "countries" do
    country_fields()

    # Your own fields go alongside.
    field :verified, :boolean, default: true

    timestamps(type: :utc_datetime)
  end
end
```

Both take the same options:

| Option        | Values | Default |
| ------------- | ------ | ------- |
| `primary_key` | `:uuid`, generated in Elixir, or `:integer`, auto-incremented by the database | `:uuid` |
| `arrays`      | `:native` for databases with an array type, or `:json` to store lists as JSON text | `:native` |

```elixir
Countries.Migration.create_table(:countries, primary_key: :integer, arrays: :json)
use Countries.Schema, primary_key: :integer, arrays: :json
```

`create_table/2` adds unique indexes on `alpha_3` and `code` and an index on `name`.
For a table laid out by hand, use `Countries.Migration.columns/1` and `indexes/1`.

## Databases and adapters

The store decides what to change, and an adapter performs the reads and writes. An
Ecto repo is matched to its adapter automatically:

| Database   | Ecto adapter             | Countries adapter             | Lists      |
| ---------- | ------------------------ | ----------------------------- | ---------- |
| PostgreSQL | `Ecto.Adapters.Postgres` | `Countries.Adapters.Postgres` | `:native`  |
| SQLite     | `Ecto.Adapters.SQLite3`  | `Countries.Adapters.SQLite3`  | `:native`  |
| MySQL      | `Ecto.Adapters.MyXQL`    | `Countries.Adapters.MySQL`    | `:json`    |

PostgreSQL and SQLite are covered by the test suite. MySQL is not yet.

Writes use plain inserts and per-row updates, so the database needs no upsert support.
A unique index on the store's `key` is still advised.

### Another Ecto SQL database

Supply the database's case-insensitive search and its limit on bind parameters per
statement:

```elixir
defmodule MyApp.Countries.CockroachAdapter do
  use Countries.Adapters.Ecto, max_parameters: 65_535

  @impl Countries.Adapters.Ecto
  def search_query(queryable, pattern), do: where(queryable, [c], ilike(c.name, ^pattern))
end
```

```elixir
use Countries.Store, repo: MyApp.Repo, schema: MyApp.Countries.Country,
  adapter: MyApp.Countries.CockroachAdapter
```

### A database without Ecto

Implement the six callbacks of `Countries.Adapter`: `all/1`, `get/2`, `get_by/3`,
`search/2`, `load/1` and `write/3`. The store passes `repo` through unchanged, so it
can be a connection name, a pid or a module. An Ecto schema still describes the
records, and it needs no Ecto repo.

A MongoDB sketch, using `mongodb_driver`:

```elixir
defmodule MyApp.Countries.MongoAdapter do
  @behaviour Countries.Adapter

  alias Countries.Store.Config

  @impl true
  def all(%Config{repo: conn} = config), do: find(config, conn, %{}, sort: %{name: 1})

  @impl true
  def get(config, id), do: get_by(config, :_id, id)

  @impl true
  def get_by(%Config{repo: conn} = config, field, value) do
    config |> find(conn, %{field => value}, limit: 1) |> List.first()
  end

  @impl true
  def search(%Config{repo: conn} = config, term) do
    regex = %BSON.Regex{pattern: Regex.escape(term), options: "i"}
    find(config, conn, %{name: regex}, sort: %{name: 1})
  end

  @impl true
  def load(%Config{repo: conn, schema: schema, owned: owned}) do
    projection = Map.new(owned, &{&1, 1})

    conn
    |> Mongo.find(collection(schema), %{}, projection: projection)
    |> Enum.map(&Map.new(owned, fn field -> {field, &1[Atom.to_string(field)]} end))
  end

  @impl true
  def write(%Config{repo: conn, schema: schema, key: key}, inserts, updates) do
    Mongo.insert_many(conn, collection(schema), inserts)

    Enum.each(updates, fn {value, changes} ->
      Mongo.update_one(conn, collection(schema), %{key => value}, %{"$set" => changes})
    end)
  end

  defp find(%Config{schema: schema}, conn, filter, opts) do
    conn
    |> Mongo.find(collection(schema), filter, opts)
    |> Enum.map(&Ecto.embedded_load(schema, &1, :json))
  end

  defp collection(schema), do: schema.__schema__(:source)
end
```

```elixir
use Countries.Store, repo: :mongo, schema: MyApp.Countries.Country,
  adapter: MyApp.Countries.MongoAdapter
```

The sketch shows the shape only. A production adapter needs error handling and
transactions. `test/support/memory_adapter.ex` is a complete adapter with no Ecto
repo behind it, and makes a good reference.

## Updating the dataset

The dataset lives in `priv/countries.json`, one country per line, so every change
reads as a one-line diff.

1. Edit `priv/countries.json`. To reformat it after a hand edit, see
   `Countries.Dataset.encode/1`.
2. Run `mix test`. It fails if the file is malformed, a code is duplicated, or the
   layout drifts.
3. Add an entry to `CHANGELOG.md`, bump `@version` in `mix.exs`, and tag the release.

Applications then upgrade the dependency, review with `diff/0`, and run `sync/0`.

A field added to the dataset is ignored until an application's schema has it, so
upgrading never forces a migration.

## Development

```sh
mix test   # SQLite always; PostgreSQL when reachable
mix lint   # format check, credo --strict, dialyzer
mix docs   # API documentation in doc/
```

PostgreSQL tests connect with `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_HOST`
and `DATABASE_PORT`, which default to `postgres`/`postgres` on `localhost:5432`.

The library supports Elixir 1.15 and later. Running its test suite needs 1.18 or later.
