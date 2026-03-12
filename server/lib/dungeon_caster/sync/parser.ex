defmodule DungeonCaster.Sync.Parser do
  @moduledoc "Parses Markdown files with YAML frontmatter into entity data maps."

  @type_to_dir %{
    "npc" => "npcs",
    "location" => "locations",
    "faction" => "factions",
    "session" => "sessions",
    "stat-block" => "stat-blocks",
    "map" => "maps",
    "audio" => "audio"
  }

  @doc """
  Parses a campaign entity Markdown file.
  Returns {:ok, type, data_map} or {:error, reason}.
  """
  def parse_file(path) do
    with {:ok, content} <- File.read(path),
         {:ok, fm_str, body} <- split_frontmatter(content),
         {:ok, data} <- parse_yaml(fm_str),
         {:ok, type} <- validate_type(data, path),
         {:ok, html} <- render_markdown(body) do
      enriched =
        Map.merge(data, %{
          "body_raw" => body,
          "body_html" => html,
          "file_path" => path
        })

      {:ok, type, enriched}
    end
  end

  defp split_frontmatter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [fm, body] -> {:ok, fm, String.trim_leading(body)}
      _ -> {:error, :no_closing_frontmatter}
    end
  end

  defp split_frontmatter(_), do: {:error, :no_frontmatter}

  defp parse_yaml(fm_str) do
    case YamlElixir.read_from_string(fm_str) do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:ok, _} -> {:error, :yaml_not_a_map}
      {:error, reason} -> {:error, {:yaml_parse_error, reason}}
    end
  end

  defp validate_type(%{"type" => type}, path) do
    dir = path |> Path.dirname() |> Path.basename()

    case Map.get(@type_to_dir, type) do
      nil ->
        {:error, "unknown entity type: #{type}"}

      expected_dir when expected_dir == dir ->
        {:ok, type}

      expected_dir ->
        {:error, "type '#{type}' expects directory '#{expected_dir}', got '#{dir}'"}
    end
  end

  defp validate_type(_, _), do: {:error, :missing_type_field}

  defp render_markdown(body) do
    {:ok, DungeonCaster.Markdown.render(body)}
  end
end
