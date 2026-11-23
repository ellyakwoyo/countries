defmodule Countries.SchemaTest do
  use ExUnit.Case, async: true

  alias Countries.Test.{Country, IntegerCountry}

  test "defaults to a uuid primary key and native lists" do
    assert Country.__schema__(:type, :id) == :binary_id
    assert Country.__schema__(:type, :aliases) == {:array, :string}
  end

  test "takes an integer primary key and JSON lists" do
    assert IntegerCountry.__schema__(:type, :id) == :id
    assert IntegerCountry.__schema__(:type, :aliases) == Countries.Types.JSONList
  end

  test "defines every dataset column" do
    columns = Keyword.keys(Countries.Country.columns())

    assert columns -- Country.__schema__(:fields) == []
  end

  test "rejects unknown options" do
    assert_raise ArgumentError, ~r/:primary_key must be/, fn ->
      Countries.Schema.__keys__(:serial)
    end

    assert_raise ArgumentError, ~r/:arrays must be/, fn -> Countries.Schema.__fields__(:csv) end
  end

  test "the dataset file is in canonical layout" do
    file = File.read!(Countries.Dataset.path())

    assert file |> Countries.Dataset.decode() |> Countries.Dataset.encode() == file
  end
end
