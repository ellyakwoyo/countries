defmodule Countries.Test.MemoryAdapter do
  @moduledoc """
  A `Countries.Adapter` with no Ecto repo behind it, holding records in the calling
  process. It stands in for non-SQL databases such as MongoDB.
  """

  @behaviour Countries.Adapter

  alias Countries.Store.Config

  @impl true
  def all(%Config{schema: schema}), do: schema |> records() |> Enum.sort_by(& &1.name)

  @impl true
  def get(%Config{} = config, id), do: get_by(config, :id, id)

  @impl true
  def get_by(%Config{schema: schema}, field, value) do
    schema |> records() |> Enum.find(&(Map.fetch!(&1, field) == value))
  end

  @impl true
  def search(%Config{} = config, term) do
    term = String.downcase(term)
    config |> all() |> Enum.filter(&String.contains?(String.downcase(&1.name), term))
  end

  @impl true
  def load(%Config{schema: schema, owned: owned}) do
    schema |> records() |> Enum.map(&Map.take(&1, owned))
  end

  @impl true
  def write(%Config{schema: schema, key: key}, inserts, updates) do
    inserted = Enum.map(inserts, &struct!(schema, Map.put(&1, :id, Ecto.UUID.generate())))
    changes = Map.new(updates)

    schema
    |> records()
    |> Enum.map(&struct!(&1, Map.get(changes, Map.fetch!(&1, key), %{})))
    |> Kernel.++(inserted)
    |> then(&Process.put({__MODULE__, schema}, &1))

    :ok
  end

  defp records(schema), do: Process.get({__MODULE__, schema}, [])
end
