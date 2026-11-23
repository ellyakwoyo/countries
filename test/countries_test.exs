defmodule CountriesTest do
  use ExUnit.Case, async: true

  alias Countries.Country

  doctest Countries

  describe "the dataset" do
    test "has unique alpha-3 and two-letter codes" do
      all = Countries.all()

      assert length(all) == length(Enum.uniq_by(all, & &1.alpha_3))
      assert length(all) == length(Enum.uniq_by(all, & &1.code))
    end

    test "loads every field as a struct" do
      assert %Country{dial_code: "+254", is_country: true, iso_codes: ["KE", "KEN"]} =
               Countries.get("KEN")
    end
  end

  describe "fetch/1" do
    test "wraps the result" do
      assert {:ok, %Country{alpha_3: "UGA"}} = Countries.fetch("uga")
      assert Countries.fetch("ZZZ") == :error
    end
  end

  describe "resolve/1" do
    test "prefers an exact code over a name or alias" do
      assert Countries.resolve("D").alpha_3 == "D"
      assert Countries.resolve("Germany").alpha_3 == "DEU"
    end

    test "reads ICAO and legacy codes" do
      assert Countries.resolve("XXA").alpha_3 == "XXA"
      assert Countries.resolve("KOS").alpha_3 == "XKX"
    end

    test "reads nationalities, former names and scanner spellings" do
      assert Countries.resolve("Kenyan").alpha_3 == "KEN"
      assert Countries.resolve("Tanzania").alpha_3 == "TZA"
      assert Countries.resolve("BRITISH CITIZEN").alpha_3 == "GBR"
    end

    test "returns nil for blank or unknown values" do
      assert Countries.resolve("") == nil
      assert Countries.resolve("   ") == nil
      assert Countries.resolve("Atlantis") == nil
    end
  end
end
