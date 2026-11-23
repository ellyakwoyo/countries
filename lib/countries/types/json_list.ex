defmodule Countries.Types.JSONList do
  @moduledoc """
  A list of strings stored as JSON text, for engines without an array type, such as
  MySQL.

  `Countries.Schema` and `Countries.Migration` use it for the list columns when given
  `arrays: :json`.
  """

  use Ecto.Type

  @impl true
  def type, do: :string

  @impl true
  def cast(list) when is_list(list), do: {:ok, list}
  def cast(_value), do: :error

  @impl true
  def dump(list) when is_list(list), do: {:ok, Jason.encode!(list)}
  def dump(_value), do: :error

  @impl true
  def load(json) when is_binary(json), do: Jason.decode(json)
  def load(_value), do: :error
end
