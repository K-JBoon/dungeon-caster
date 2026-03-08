defmodule CampaignTool.Entities.Types.StringList do
  @moduledoc "Custom Ecto type: JSON-serialized list of strings, stored as TEXT in SQLite."
  use Ecto.Type

  def type, do: :string

  def cast(nil), do: {:ok, []}
  def cast(list) when is_list(list), do: {:ok, Enum.map(list, &to_string/1)}
  def cast(_), do: :error

  def dump(list) when is_list(list) do
    case Jason.encode(list) do
      {:ok, json} -> {:ok, json}
      _ -> :error
    end
  end
  def dump(_), do: :error

  def load(nil), do: {:ok, []}
  def load(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _ -> :error
    end
  end
  def load(_), do: :error

  def equal?(a, b), do: a == b
end
