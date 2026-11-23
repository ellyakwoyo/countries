defmodule Countries.CountryTest do
  use ExUnit.Case, async: true

  alias Countries.Country

  doctest Countries.Lookup

  @kenya Country.new(%{
           alpha_3: "KEN",
           code: "KE",
           name: "Kenya",
           iso_codes: ["KE", "KEN"],
           nationalities: ["Kenyan"],
           aliases: ["Jamhuri ya Kenya"],
           scanner_aliases: []
         })

  test "new/1 rejects unknown keys" do
    assert_raise KeyError, fn -> Country.new(%{alpha_3: "KEN", code: "KE", name: "K", x: 1}) end
  end

  test "lookup_values/1 lists codes first, then names, without duplicates" do
    assert Country.lookup_values(@kenya) == ["KEN", "KE", "Kenya", "Kenyan", "Jamhuri ya Kenya"]
  end

  test "normalized_lookup_values/1 normalises each lookup value" do
    assert Country.normalized_lookup_values(@kenya) ==
             ["KEN", "KE", "KENYA", "KENYAN", "JAMHURIYAKENYA"]
  end

  test "attributes/1 includes the derived columns" do
    attributes = Country.attributes(@kenya)

    assert attributes.lookup_values == Country.lookup_values(@kenya)
    assert Map.keys(attributes) -- Keyword.keys(Country.columns()) == []
  end
end
