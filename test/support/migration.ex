defmodule Countries.Test.Migration do
  @moduledoc false
  use Ecto.Migration

  def change do
    Countries.Migration.create_table()
    Countries.Migration.create_table(:integer_countries, primary_key: :integer, arrays: :json)

    create table(:legacy_countries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :code, :string, null: false
      add :alpha_3, :string
      add :unicode, :string
      add :is_country, :boolean
      add :iso_codes, {:array, :string}, default: []
      add :is_frequently_selected, :boolean, default: false
      add :display_name, :string
      add :verified, :boolean, default: true
      timestamps()
    end

    create unique_index(:legacy_countries, [:code])
  end
end
