defmodule Countries do
  @moduledoc """
  Shared country reference data.

  The dataset (see `Countries.Dataset`) is compiled into this module, so reading it
  needs no database and no process. To keep a database table in step with it, see
  `Countries.Store`.

  ## Examples

      iex> Countries.get("KEN").name
      "Kenya"

      iex> Countries.resolve("tanzanian").alpha_3
      "TZA"

  """

  alias Countries.{Country, Dataset, Lookup}

  @external_resource Dataset.path()

  @countries Dataset.path()
             |> File.read!()
             |> Dataset.decode()
             |> Enum.sort_by(& &1.name)

  @by_alpha_3 Map.new(@countries, &{&1.alpha_3, &1})
  @index Lookup.index(@countries)

  @doc """
  Every country in the dataset, ordered by name.
  """
  @spec all() :: [Country.t()]
  def all, do: @countries

  @doc """
  The countries whose fields equal every given value, ordered by name.

  ## Examples

      iex> Countries.where(is_country: true, dial_code: "+254") |> Enum.map(& &1.alpha_3)
      ["KEN"]

  """
  @spec where(keyword()) :: [Country.t()]
  def where(clauses) when is_list(clauses) do
    Enum.filter(@countries, &matches?(&1, clauses))
  end

  @doc """
  The country with the given alpha-3 code, in any case, or `nil`.

  ## Examples

      iex> Countries.get("ken").code
      "KE"

      iex> Countries.get("ZZZ")
      nil

  """
  @spec get(String.t()) :: Country.t() | nil
  def get(alpha_3) when is_binary(alpha_3), do: Map.get(@by_alpha_3, String.upcase(alpha_3))

  @doc """
  Like `get/1`, but returns `{:ok, country}` or `:error`.
  """
  @spec fetch(String.t()) :: {:ok, Country.t()} | :error
  def fetch(alpha_3) when is_binary(alpha_3), do: Map.fetch(@by_alpha_3, String.upcase(alpha_3))

  @doc """
  Finds the country a free-text value refers to, or returns `nil`.

  Matches alpha-3 and two-letter codes, other ISO and ICAO codes, names, former names,
  nationalities and scanner spellings, ignoring case, accents and punctuation. See
  `Countries.Lookup.index/1` for how ties are broken.

  ## Examples

      iex> Countries.resolve("Côte d'Ivoire").alpha_3
      "CIV"

      iex> Countries.resolve("SYRIA").name
      "Syrian Arab Republic"

      iex> Countries.resolve("Atlantis")
      nil

  """
  @spec resolve(String.t() | nil) :: Country.t() | nil
  def resolve(nil), do: nil

  def resolve(value) when is_binary(value) do
    Map.get(@by_alpha_3, Map.get(@index, Lookup.normalize(value)))
  end

  defp matches?(country, clauses) do
    Enum.all?(clauses, fn {field, value} -> Map.fetch!(country, field) == value end)
  end
end
