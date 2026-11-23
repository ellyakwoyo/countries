defmodule Countries.Lookup do
  @moduledoc """
  Normalises free-text country values so they can be matched reliably.

  Passport scanners, MRZ lines, forms and legacy data spell the same country in many
  ways: `"Côte d'Ivoire"`, `"COTE D IVOIRE"`, `"St. Vincent & Grenadines"`. Every
  lookup value is reduced to upper-case ASCII letters and digits before matching.
  """

  alias Countries.Country

  @doc """
  Reduces `value` to upper-case ASCII letters and digits.

  Accents are stripped and `&` is read as `AND`.

  ## Examples

      iex> Countries.Lookup.normalize("  Côte d'Ivoire ")
      "COTEDIVOIRE"

      iex> Countries.Lookup.normalize("Trinidad & Tobago")
      "TRINIDADANDTOBAGO"

  """
  @spec normalize(String.t()) :: String.t()
  def normalize(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.upcase()
    |> String.replace("&", "AND")
    |> String.replace(~r/[^A-Z0-9]/u, "")
  end

  @doc """
  Builds a map of normalised lookup value to alpha-3 code.

  When two countries share a value, the stronger match wins: an alpha-3 code beats a
  two-letter code, which beats another ISO code, which beats a name, nationality or
  alias. Within the same kind of match, a sovereign country (`is_country: true`) beats
  a territory or special code.
  """
  @spec index([Country.t()]) :: %{String.t() => String.t()}
  def index(countries) do
    ranked = Enum.sort_by(countries, & &1.is_country)

    for values <- [&Country.names/1, & &1.iso_codes, &[&1.code], &[&1.alpha_3]],
        country <- ranked,
        key <- Enum.map(values.(country), &normalize/1),
        key != "",
        into: %{},
        do: {key, country.alpha_3}
  end
end
