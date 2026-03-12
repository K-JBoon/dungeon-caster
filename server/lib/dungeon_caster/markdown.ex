defmodule DungeonCaster.Markdown do
  alias DungeonCaster.Entities.TypeMeta

  @badge_re ~r/~\[([^\]]+)\]\{([^}]+)\}/

  @doc """
  Renders markdown to HTML, converting ~[Name]{type:id} refs to clickable badge spans.
  """
  def render(nil), do: ""
  def render(""), do: ""

  def render(raw) when is_binary(raw) do
    raw
    # escape: false is required — without it, Earmark escapes the ~[...]{} syntax
    # before our postprocessor can match it.
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
    |> Enum.uniq_by(fn %{type: t, id: id} -> {t, id} end)
  end

  def extract_entity_refs(_), do: []

  defp escape_html(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp postprocess_entity_refs(html) do
    Regex.replace(@badge_re, html, fn _, name, ref ->
      safe_name = escape_html(name)
      safe_ref = escape_html(ref)
      type = ref |> String.split(":", parts: 2) |> List.first()
      icon = type |> TypeMeta.icon() |> escape_html()

      ~s(<span class="entity-badge" data-ref="#{safe_ref}" data-display="#{safe_name}" ) <>
        ~s(phx-click="open_entity_popover" phx-value-ref="#{safe_ref}">) <>
        ~s(<span class="entity-badge__icon #{icon} size-3" aria-hidden="true"></span>) <>
        ~s(<span class="entity-badge__label">#{safe_name}</span></span>)
    end)
  end
end
