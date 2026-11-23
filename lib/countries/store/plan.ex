defmodule Countries.Store.Plan do
  @moduledoc """
  What a sync would change, worked out before anything is written.

    * `:insert` - dataset rows the table lacks.
    * `:update` - rows whose owned fields differ from the dataset, with each
      difference as `{current, dataset}`.
    * `:unknown` - keys in the table the dataset lacks. Sync never deletes them.

  `Countries.Store.diff/1` returns a plan so a table can be reviewed before it is
  synced.
  """

  defstruct insert: [], update: [], unknown: []

  @type row :: %{atom() => term()}
  @type update :: %{key: term(), changes: %{atom() => {term(), term()}}}
  @type t :: %__MODULE__{insert: [row()], update: [update()], unknown: [term()]}

  @doc """
  Compares the `desired` rows with the `current` ones, matching them on `key`.

  Only the fields a current row holds are compared, so a field left out of `current`
  is written when its row is inserted but never updated.

  ## Examples

      iex> desired = [%{code: "KE", name: "Kenya"}, %{code: "UG", name: "Uganda"}]
      iex> current = [%{code: "KE", name: "Kenia"}, %{code: "ZZ", name: "Old"}]
      iex> plan = Countries.Store.Plan.build(desired, current, :code)
      iex> Enum.map(plan.insert, & &1.code)
      ["UG"]
      iex> plan.update
      [%{key: "KE", changes: %{name: {"Kenia", "Kenya"}}}]
      iex> plan.unknown
      ["ZZ"]

  """
  @spec build([row()], [row()], atom()) :: t()
  def build(desired, current, key) do
    current_by_key = Map.new(current, &{Map.fetch!(&1, key), &1})
    desired_keys = MapSet.new(desired, &Map.fetch!(&1, key))

    %__MODULE__{
      insert: Enum.reject(desired, &Map.has_key?(current_by_key, Map.fetch!(&1, key))),
      update: updates(desired, current_by_key, key),
      unknown: current_by_key |> Map.keys() |> Enum.reject(&(&1 in desired_keys)) |> Enum.sort()
    }
  end

  @doc """
  Whether the plan changes nothing.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{insert: [], update: []}), do: true
  def empty?(%__MODULE__{}), do: false

  defp updates(desired, current_by_key, key) do
    for row <- desired,
        {:ok, current} <- [Map.fetch(current_by_key, Map.fetch!(row, key))],
        changes = changes(current, row),
        changes != %{},
        do: %{key: Map.fetch!(row, key), changes: changes}
  end

  defp changes(current, row) do
    for {field, value} <- current,
        Map.fetch!(row, field) != value,
        into: %{},
        do: {field, {value, Map.fetch!(row, field)}}
  end
end
