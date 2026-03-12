defmodule DungeonCasterWeb.EntityHelpers do
  alias DungeonCaster.{Audio, Entities}
  alias DungeonCaster.Entities.TypeMeta
  alias Phoenix.HTML

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

      _ ->
        nil
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

  def entity_type_icon(type), do: TypeMeta.icon(type)

  @doc """
  Builds popover data map for a given "type:id" ref.
  Returns {:ok, %{ref, name, type, html}} or :error.
  """
  def entity_popover_data(ref) do
    case load_entity_from_ref(ref) do
      {type, entity} ->
        name = Map.get(entity, :name) || Map.get(entity, :title) || entity.id

        body_html =
          if entity.body_html && entity.body_html != "",
            do: entity.body_html,
            else: ""

        payload = %{ref: ref, name: name, type: type, html: body_html}

        payload =
          if type == "audio" do
            asset_path = normalized_audio_asset_path(entity.asset_path)
            playable = audio_playable?(entity)

            Map.merge(payload, %{
              html: audio_popover_html(body_html, asset_path, entity.category, playable),
              playable: playable,
              category: entity.category,
              asset_path: asset_path
            })
          else
            payload
          end

        {:ok, payload}

      nil ->
        :error
    end
  end

  defp audio_playable?(%{asset_path: asset_path})
       when is_binary(asset_path) and asset_path != "" do
    Audio.audio_file_available?(asset_path)
  end

  defp audio_playable?(_), do: false

  defp normalized_audio_asset_path(asset_path) when is_binary(asset_path) and asset_path != "" do
    Audio.asset_url(asset_path) |> String.trim_leading("/audio/")
  end

  defp normalized_audio_asset_path(_), do: nil

  defp audio_popover_html(body_html, asset_path, category, true) do
    label = if category == "sfx", do: "Play SFX", else: "Play"
    escaped_path = html_escape(asset_path)
    escaped_category = html_escape(category)
    escaped_label = html_escape(label)

    """
    <div class="entity-popover-audio-action not-prose mb-4">
      <button
        type="button"
        class="entity-popover-audio-play"
        phx-click="play_audio_entity"
        phx-value-asset_path="#{escaped_path}"
        phx-value-category="#{escaped_category}"
        title="#{escaped_label}"
      >
        <span class="entity-popover-audio-play-icon" aria-hidden="true">▶</span>
        <span>#{escaped_label}</span>
      </button>
    </div>
    #{body_html}
    """
  end

  defp audio_popover_html(body_html, _asset_path, _category, false), do: body_html

  defp html_escape(value) do
    value
    |> to_string()
    |> HTML.html_escape()
    |> HTML.safe_to_string()
  end
end
