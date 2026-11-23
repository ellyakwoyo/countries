defmodule Countries.MemoryStoreTest do
  use ExUnit.Case, async: true

  alias Countries.Store.Plan
  alias Countries.Test.{MemoryAdapter, MemoryStore}

  @total length(Countries.all())

  test "syncs, diffs and reads through an adapter with no Ecto repo" do
    assert {:ok, %{inserted: @total, updated: 0}} = MemoryStore.sync()
    assert Plan.empty?(MemoryStore.diff())

    kenya = MemoryStore.resolve("Kenyan")

    assert MemoryStore.get(kenya.id) == kenya
    assert ["TZA"] = "tanz" |> MemoryStore.search() |> Enum.map(& &1.alpha_3)
  end

  test "updates only what changed" do
    MemoryStore.sync()
    Process.put({MemoryAdapter, Countries.Test.Country}, rename_kenya())

    assert %Plan{update: [%{key: "KEN", changes: %{name: {"Kenia", "Kenya"}}}]} =
             MemoryStore.diff()

    assert {:ok, %{updated: 1}} = MemoryStore.sync()
    assert MemoryStore.resolve("KEN").name == "Kenya"
  end

  defp rename_kenya, do: Enum.map(MemoryStore.all(), &rename(&1, &1.alpha_3))

  defp rename(country, "KEN"), do: %{country | name: "Kenia"}
  defp rename(country, _alpha_3), do: country
end
