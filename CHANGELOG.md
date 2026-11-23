# Changelog

## v0.1.0

- 263 countries, territories and document codes, with aliases, nationalities and
  scanner spellings for lookups.
- `Countries`: in-memory reads and free-text `resolve/1`.
- `Countries.Store`: `diff/1` and `sync/1` for a project's own table.
- `Countries.Adapter`: database-agnostic adapters, with PostgreSQL, SQLite and MySQL
  built in.
- `Countries.Schema` and `Countries.Migration` for new projects, with `:uuid` (the
  default) or `:integer` primary keys, and native or JSON list columns.
