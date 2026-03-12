defmodule DungeonCasterWeb.EntityHelpers do
  alias DungeonCaster.Entities

  @doc """
  Parses "type:id" ref string and loads entity from DB.
  Returns {type, entity} or nil.
  """
  def load_entity_from_ref(ref) when is_binary(ref) do
    case String.split(ref, ":", parts: 2) do
      [type, id] ->
        case Entities.get_entity(type, id) do
          nil -> nil
          entity -> {type, entity}
        end
      _ -> nil
    end
  end
  def load_entity_from_ref(_), do: nil

  @doc """
  Searches entities via FTS5, returns up to 8 results.
  Results are %{type, id, name} maps.
  """
  def search_entities(q) when is_binary(q) and byte_size(q) > 1 do
    Entities.search(q)
    |> Enum.reject(&(&1.type == "session"))
    |> Enum.take(8)
  end
  def search_entities(_), do: []

  @doc """
  Builds popover data map for a given "type:id" ref.
  Returns {:ok, %{ref, name, type, html}} or :error.
  """
  def entity_popover_data(ref) do
    case load_entity_from_ref(ref) do
      {type, entity} ->
        name = Map.get(entity, :name) || Map.get(entity, :title) || entity.id
        html =
          if entity.body_html && entity.body_html != "",
            do: entity.body_html,
            else: ""

        payload = %{ref: ref, name: name, type: type, html: html}

        payload =
          if type == "audio" do
            Map.merge(payload, %{
              category: entity.category,
              asset_path: entity.asset_path
            })
          else
            payload
          end

        {:ok, payload}
      nil ->
        :error
    end
  end
end
