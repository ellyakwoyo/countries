defmodule Countries.Dataset do
  @moduledoc """
  Reads and writes `priv/countries.json`, the dataset every project shares.

  The file is the source of truth. Every change is made here and released;
  applications pick it up by upgrading the library and running their store's
  `diff/0` and `sync/0`.

  The file holds one country per line, ordered by alpha-3 code with keys sorted, so a
  change reads as a one-line diff. `encode/1` produces that layout, and the test suite
  fails if the file drifts from it.
  """

  alias Countries.Country

  @path Path.expand("../../priv/countries.json", __DIR__)

  @doc "Where the dataset file lives."
  @spec path() :: Path.t()
  def path, do: @path

  @doc "Parses dataset JSON into countries."
  @spec decode(iodata()) :: [Country.t()]
  def decode(json) do
    json
    |> Jason.decode!()
    |> Enum.map(&Country.from_json/1)
  end

  @doc """
  Serialises countries in the dataset file layout.

  To reformat the file after editing it by hand:

      Countries.Dataset.path()
      |> File.read!()
      |> Countries.Dataset.decode()
      |> Countries.Dataset.encode()
      |> then(&File.write!(Countries.Dataset.path(), &1))

  """
  @spec encode([Country.t()]) :: String.t()
  def encode(countries) when is_list(countries) do
    lines =
      countries
      |> Enum.sort_by(& &1.alpha_3)
      |> Enum.map_join(",\n", &("  " <> encode_country(&1)))

    "[\n" <> lines <> "\n]\n"
  end

  defp encode_country(country) do
    country
    |> Map.from_struct()
    |> Enum.sort()
    |> Jason.OrderedObject.new()
    |> Jason.encode!()
  end
end
