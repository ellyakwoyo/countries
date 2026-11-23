defmodule Countries.Test.Country do
  @moduledoc false
  use Countries.Schema

  schema "countries" do
    country_fields()
    timestamps(type: :utc_datetime)
  end
end

defmodule Countries.Test.IntegerCountry do
  @moduledoc "An auto-incremented key, with lists stored as JSON as on MySQL."
  use Countries.Schema, primary_key: :integer, arrays: :json

  schema "integer_countries" do
    country_fields()
    timestamps(type: :utc_datetime)
  end
end

defmodule Countries.Test.LegacyCountry do
  @moduledoc """
  Shaped like a live project's table: a subset of the dataset columns, matched on
  `code`, plus columns only the project writes.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "legacy_countries" do
    field :name, :string
    field :code, :string
    field :alpha_3, :string
    field :unicode, :string
    field :is_country, :boolean
    field :iso_codes, {:array, :string}, default: []
    field :is_frequently_selected, :boolean, default: false
    field :display_name, :string
    field :verified, :boolean, default: true
    timestamps(type: :naive_datetime)
  end
end
