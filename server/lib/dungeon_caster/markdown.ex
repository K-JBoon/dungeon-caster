defmodule DungeonCaster.Markdown do
  @badge_re ~r/~\[([^\]]+)\]\{([^}]+)\}/

  @doc """
  Renders markdown to HTML, converting ~[Name]{type:id} refs to clickable badge spans.
  """
  def render(""), do: ""
  def render(raw) when is_binary(raw) do
    raw
    |> Earmark.as_html!(escape: false)
    |> postprocess_entity_refs()
  end

  @doc """
  Extracts all ~[Name]{type:id} refs from raw markdown, deduplicated by type:id.
  Returns a list of %{type, id, display_name} maps.
  """
  def extract_entity_refs(raw) when is_binary(raw) do
    @badge_re
    |> Regex.scan(raw, capture: :all_but_first)
    |> Enum.map(fn [name, ref] ->
      case String.split(ref, ":", parts: 2) do
        [type, id] -> %{type: type, id: id, display_name: name}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn %{type: t, id: id} -> "#{t}:#{id}" end)
  end
  def extract_entity_refs(_), do: []

  defp postprocess_entity_refs(html) do
    Regex.replace(@badge_re, html, fn _, name, ref ->
      ~s(<span class="entity-badge" data-ref="#{ref}" data-display="#{name}" ) <>
      ~s(phx-click="open_entity_popover" phx-value-ref="#{ref}">#{name}</span>)
    end)
  end
end
