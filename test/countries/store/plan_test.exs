defmodule Countries.Store.PlanTest do
  use ExUnit.Case, async: true

  alias Countries.Store.Plan

  doctest Plan

  test "an identical table needs no changes" do
    rows = [%{code: "KE", name: "Kenya"}]

    plan = Plan.build(rows, rows, :code)

    assert Plan.empty?(plan)
    assert plan.unknown == []
  end

  test "compares only the columns the current rows hold" do
    desired = [%{code: "KE", name: "Kenya", dial_code: "+254"}]

    plan = Plan.build(desired, [%{code: "KE", name: "Kenia"}], :code)

    assert plan.update == [%{key: "KE", changes: %{name: {"Kenia", "Kenya"}}}]
    assert Plan.empty?(Plan.build(desired, [%{code: "KE"}], :code))
  end

  test "unknown rows alone leave the plan empty" do
    assert Plan.empty?(Plan.build([], [%{code: "ZZ"}], :code))
  end
end
