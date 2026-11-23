defmodule Countries.Country do
  @moduledoc """
  A country, territory or travel-document code from the shared dataset.

  Besides sovereign states, the dataset holds territories (`is_country: false`), legacy
  codes such as `"D"` for Germany, and ICAO document codes such as `"XXA"` for
  stateless persons.

  `lookup_values/1` and `normalized_lookup_values/1` are derived from the other fields
  rather than stored, so they always agree with them.
  """

  alias Countries.Lookup

  @columns [
    alpha_3: {:string, null: false},
    code: {:string, null: false},
    name: {:string, null: false},
    display_code: {:string, []},
    dial_code: {:string, []},
    image: {:string, []},
    unicode: {:string, []},
    iso_codes: {{:array, :string}, default: []},
    is_country: {:boolean, default: false},
    is_issuer: {:boolean, default: false},
    is_exempt: {:boolean, default: false},
    days_exempt: {:integer, []},
    participation_type: {:string, default: "all"},
    is_diplomatic_exempt: {:boolean, default: false},
    is_diplomatic_exempt_days: {:integer, []},
    is_service_exempt: {:boolean, default: false},
    is_service_exempt_days: {:integer, []},
    is_special_exempt: {:boolean, default: false},
    is_special_exempt_days: {:integer, []},
    is_3a: {:boolean, default: false},
    is_common_wealth: {:boolean, default: false},
    is_gratis: {:boolean, default: false},
    is_high_risk: {:boolean, default: false},
    is_frequently_selected: {:boolean, default: false},
    notes: {:string, []},
    aliases: {{:array, :string}, default: []},
    nationalities: {{:array, :string}, default: []},
    scanner_aliases: {{:array, :string}, default: []},
    lookup_values: {{:array, :string}, default: []},
    normalized_lookup_values: {{:array, :string}, default: []}
  ]

  @derived [:lookup_values, :normalized_lookup_values]
  @fields Keyword.keys(@columns) -- @derived

  @enforce_keys [:alpha_3, :code, :name]
  defstruct for field <- @fields, do: {field, @columns[field] |> elem(1) |> Keyword.get(:default)}

  @type t :: %__MODULE__{
          alpha_3: String.t(),
          code: String.t(),
          name: String.t(),
          display_code: String.t() | nil,
          dial_code: String.t() | nil,
          image: String.t() | nil,
          unicode: String.t() | nil,
          iso_codes: [String.t()],
          is_country: boolean(),
          is_issuer: boolean(),
          is_exempt: boolean(),
          days_exempt: non_neg_integer() | nil,
          participation_type: String.t(),
          is_diplomatic_exempt: boolean(),
          is_diplomatic_exempt_days: non_neg_integer() | nil,
          is_service_exempt: boolean(),
          is_service_exempt_days: non_neg_integer() | nil,
          is_special_exempt: boolean(),
          is_special_exempt_days: non_neg_integer() | nil,
          is_3a: boolean(),
          is_common_wealth: boolean(),
          is_gratis: boolean(),
          is_high_risk: boolean(),
          is_frequently_selected: boolean(),
          notes: String.t() | nil,
          aliases: [String.t()],
          nationalities: [String.t()],
          scanner_aliases: [String.t()]
        }

  @typedoc "A column name, its Ecto type and its migration options."
  @type column :: {atom(), {Ecto.Type.t(), keyword()}}

  @doc "The fields stored in the dataset."
  @spec fields() :: [atom()]
  def fields, do: @fields

  @doc """
  Every column a country table can hold: the dataset fields plus the derived lookup
  columns, with their Ecto types and migration options.
  """
  @spec columns() :: [column()]
  def columns, do: @columns

  @doc """
  Builds a country from a map with atom keys, raising on unknown keys.

  Fields left out take their column default: `false`, `[]`, `"all"` or `nil`.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs), do: struct!(__MODULE__, attrs)

  @doc """
  Like `new/1`, for a decoded JSON object with string keys.
  """
  @spec from_json(%{String.t() => term()}) :: t()
  def from_json(object) when is_map(object) do
    object
    |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)
    |> new()
  end

  @doc """
  The country as a flat map of every column, derived ones included.
  """
  @spec attributes(t()) :: %{atom() => term()}
  def attributes(%__MODULE__{} = country) do
    country
    |> Map.from_struct()
    |> Map.put(:lookup_values, lookup_values(country))
    |> Map.put(:normalized_lookup_values, normalized_lookup_values(country))
  end

  @doc """
  The name, nationalities and aliases a country is known by.
  """
  @spec names(t()) :: [String.t()]
  def names(%__MODULE__{} = country) do
    [country.name | country.nationalities] ++ country.aliases ++ country.scanner_aliases
  end

  @doc """
  Every code and name the country can be looked up by, as written.
  """
  @spec lookup_values(t()) :: [String.t()]
  def lookup_values(%__MODULE__{} = country) do
    ([country.alpha_3, country.code] ++ country.iso_codes ++ names(country))
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  @doc """
  `lookup_values/1`, normalised with `Countries.Lookup.normalize/1`.
  """
  @spec normalized_lookup_values(t()) :: [String.t()]
  def normalized_lookup_values(%__MODULE__{} = country) do
    country
    |> lookup_values()
    |> Enum.map(&Lookup.normalize/1)
    |> Enum.uniq()
  end
end
