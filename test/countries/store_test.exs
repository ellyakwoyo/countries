defmodule Countries.StoreTest do
  # Runs once per reachable engine. Under each engine's namespace, `Store` syncs a
  # table made with `Countries.Migration`, `IntegerStore` one with an integer key and
  # JSON lists, and `LegacyStore` one shaped like a live project's.
  alias Countries.Store.Plan
  alias Countries.Test.{Country, IntegerCountry, LegacyCountry, Setup}
  alias Ecto.Adapters.SQL.Sandbox

  use ExUnit.Case, parameterize: Setup.engines()

  import Ecto.Query

  @total length(Countries.all())

  setup %{repo: repo, stores: stores} do
    :ok = Sandbox.checkout(repo)

    %{
      store: Module.concat(stores, Store),
      integer: Module.concat(stores, IntegerStore),
      legacy: Module.concat(stores, LegacyStore)
    }
  end

  describe "sync/1" do
    test "inserts the dataset into an empty table, then has nothing left to do", ctx do
      assert {:ok, %{inserted: @total, updated: 0}} = ctx.store.sync()
      assert ctx.repo.aggregate(Country, :count) == @total

      assert {:ok, %{inserted: 0, updated: 0}} = ctx.store.sync()
      assert Plan.empty?(ctx.store.diff())
    end

    test "round-trips array and derived columns", ctx do
      ctx.store.sync()

      brazil = ctx.repo.get_by!(Country, alpha_3: "BRA")

      assert brazil.iso_codes == ["BR", "BRA"]
      assert "Brazilian" in brazil.nationalities
      assert "BRAZILIAN" in brazil.normalized_lookup_values
    end

    test "repairs drift on upsert and reports it in the diff first", ctx do
      ctx.store.sync()
      drift!(ctx.repo, Country, "KEN", name: "Kenia", iso_codes: ["KE"])

      assert %Plan{insert: [], update: [update]} = ctx.store.diff()
      assert update.key == "KEN"
      assert update.changes == %{name: {"Kenia", "Kenya"}, iso_codes: {["KE"], ["KE", "KEN"]}}

      assert {:ok, %{inserted: 0, updated: 1}} = ctx.store.sync()

      assert %{name: "Kenya", iso_codes: ["KE", "KEN"]} =
               ctx.repo.get_by!(Country, alpha_3: "KEN")
    end

    test "leaves existing rows alone in :insert mode", ctx do
      ctx.store.sync()
      drift!(ctx.repo, Country, "KEN", name: "Kenia")
      ctx.repo.delete_all(where(Country, alpha_3: "UGA"))

      assert {:ok, %{inserted: 1, updated: 0}} = ctx.store.sync(mode: :insert)
      assert ctx.repo.get_by!(Country, alpha_3: "KEN").name == "Kenia"
      assert ctx.repo.get_by(Country, alpha_3: "UGA")
    end

    test "fills the columns in :except on insert but never updates them", ctx do
      ctx.store.sync()
      drift!(ctx.repo, Country, "KEN", name: "Kenia", dial_code: "+000")
      ctx.repo.delete_all(where(Country, alpha_3: "UGA"))

      assert {:ok, %{inserted: 1, updated: 1}} = ctx.store.sync(except: [:name])
      assert %{name: "Kenia", dial_code: "+254"} = ctx.repo.get_by!(Country, alpha_3: "KEN")
      assert ctx.repo.get_by!(Country, alpha_3: "UGA").name == "Uganda"
    end

    test "reports rows missing from the dataset without deleting them", ctx do
      ctx.repo.insert!(%Country{alpha_3: "ZZZ", code: "ZZ", name: "Atlantis"})

      assert %Plan{unknown: ["ZZZ"]} = ctx.store.diff()
      assert {:ok, _result} = ctx.store.sync()
      assert ctx.repo.get_by(Country, alpha_3: "ZZZ")
    end
  end

  describe "sync/1 with an integer key and JSON lists" do
    test "lets the database assign ids and round-trips lists", ctx do
      assert {:ok, %{inserted: @total}} = ctx.integer.sync()

      brazil = ctx.repo.get_by!(IntegerCountry, alpha_3: "BRA")

      assert is_integer(brazil.id)
      assert brazil.iso_codes == ["BR", "BRA"]
      assert ctx.integer.get(brazil.id) == brazil
      assert Plan.empty?(ctx.integer.diff())
    end

    test "updates JSON lists", ctx do
      ctx.integer.sync()
      drift!(ctx.repo, IntegerCountry, "KEN", iso_codes: ["KE"])

      assert {:ok, %{updated: 1}} = ctx.integer.sync()
      assert ctx.repo.get_by!(IntegerCountry, alpha_3: "KEN").iso_codes == ["KE", "KEN"]
    end
  end

  describe "sync/1 on a live project's table" do
    test "writes only the dataset columns the schema has, matched on its key", ctx do
      assert {:ok, %{inserted: @total}} = ctx.legacy.sync()

      kenya = ctx.repo.get_by!(LegacyCountry, code: "KE")

      assert %{alpha_3: "KEN", name: "Kenya", is_country: true} = kenya
      assert %{verified: true, display_name: nil} = kenya
    end

    test "keeps project-only and excepted columns, and the insert timestamp", ctx do
      ctx.legacy.sync()
      kenya = ctx.repo.get_by!(LegacyCountry, code: "KE")

      kenya
      |> Ecto.Changeset.change(
        name: "Kenia",
        verified: false,
        display_name: "Jamhuri ya Kenya",
        is_frequently_selected: true
      )
      |> ctx.repo.update!()

      assert {:ok, %{updated: 1}} = ctx.legacy.sync()

      synced = ctx.repo.get!(LegacyCountry, kenya.id)

      assert %{name: "Kenya", verified: false, display_name: "Jamhuri ya Kenya"} = synced
      assert synced.is_frequently_selected
      assert synced.inserted_at == kenya.inserted_at
    end
  end

  describe "reads" do
    setup ctx do
      ctx.store.sync()
      ctx.legacy.sync()
      :ok
    end

    # Accented names sort by each engine's collation, so only the first row is fixed.
    test "all/0 orders by name and get/1 fetches by primary key", ctx do
      [first | _rest] = all = ctx.store.all()

      assert length(all) == @total
      assert %{name: "Afghanistan"} = first
      assert ctx.store.get(first.id) == first
    end

    test "resolve/1 finds rows from free text", ctx do
      assert ctx.store.resolve("SYRIA").alpha_3 == "SYR"
      assert ctx.store.resolve("côte d'ivoire").alpha_3 == "CIV"
      assert ctx.legacy.resolve("Brazilian").code == "BR"
      assert ctx.store.resolve("Atlantis") == nil
      assert ctx.store.resolve(nil) == nil
    end

    test "search/1 ignores case and treats wildcards literally", ctx do
      assert ["TZA"] = "tanz" |> ctx.store.search() |> Enum.map(& &1.alpha_3)
      assert ctx.store.search("%") == []
      assert ctx.store.search("_") == []
    end
  end

  describe "a live table that is never synced" do
    test "is left exactly as it is by reads and diffs", ctx do
      ctx.legacy.sync()
      drift!(ctx.repo, LegacyCountry, "KEN", name: "Republic of Kenya")
      before = ctx.repo.all(LegacyCountry)

      ctx.legacy.diff()
      ctx.legacy.all()
      ctx.legacy.resolve("Kenyan")
      ctx.legacy.search("ken")

      assert ctx.repo.all(LegacyCountry) == before
    end
  end

  defp drift!(repo, schema, alpha_3, changes) do
    schema
    |> where(alpha_3: ^alpha_3)
    |> repo.update_all(set: changes)
  end
end
