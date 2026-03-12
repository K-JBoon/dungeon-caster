defmodule DungeonCaster.Sync.RevisionHistory do
  @moduledoc """
  Reads consolidated git-backed revision history for campaign files.
  """

  @auto_save_message "Dungeon Caster auto-save"
  @default_consolidation_window_sec 900
  @log_format "%H%x1f%cI%x1f%s%x1e"

  def list_file_revisions(file_path, opts \\ []) do
    with {:ok, campaign_dir, relative_path} <- git_path(file_path),
         {output, 0} <-
           System.cmd(
             "git",
             ["log", "--follow", "--format=#{@log_format}", "--", relative_path],
             cd: campaign_dir,
             stderr_to_stdout: true
           ) do
      revisions =
        output
        |> parse_log_entries()
        |> consolidate_revisions(
          Keyword.get(opts, :window_sec, @default_consolidation_window_sec)
        )

      {:ok, revisions}
    else
      {:error, _} = error ->
        error

      {_output, _code} ->
        {:error, :git_log_failed}
    end
  end

  def read_file_revision(file_path, sha) do
    with {:ok, campaign_dir, relative_path} <- git_path(file_path),
         {content, 0} <-
           System.cmd("git", ["show", "#{sha}:#{relative_path}"],
             cd: campaign_dir,
             stderr_to_stdout: true
           ) do
      {:ok, content}
    else
      {:error, _} = error ->
        error

      {_output, _code} ->
        {:error, :git_show_failed}
    end
  end

  def extract_editor_content(content, :raw), do: content

  def extract_editor_content(content, :body) do
    case String.split(content, "\n---\n", parts: 2) do
      [_frontmatter, body] -> body
      _ -> content
    end
  end

  def extract_editor_content(content, {:scene_notes, scene_id}) do
    with {:ok, frontmatter, _body} <- split_frontmatter(content),
         {:ok, scenes_json} <- frontmatter_field(frontmatter, "scenes"),
         {:ok, scenes} <- Jason.decode(scenes_json) do
      scenes
      |> Enum.find_value("", fn scene ->
        if scene["id"] == scene_id, do: scene["notes"] || ""
      end)
    else
      _ -> ""
    end
  end

  defp git_path(file_path) do
    campaign_dir =
      Application.get_env(:dungeon_caster, :campaign_dir)
      |> Path.expand()

    expanded_path = Path.expand(file_path)
    relative_path = Path.relative_to(expanded_path, campaign_dir)

    if String.starts_with?(relative_path, "..") do
      {:error, :invalid_path}
    else
      {:ok, campaign_dir, relative_path}
    end
  end

  defp parse_log_entries(output) do
    output
    |> String.split(<<0x1E>>, trim: true)
    |> Enum.map(fn entry ->
      case String.split(entry, <<0x1F>>, parts: 3) do
        [sha, committed_at, summary] ->
          {:ok, datetime, _offset} = DateTime.from_iso8601(committed_at)

          %{
            sha: sha,
            committed_at: datetime,
            summary: summary
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp consolidate_revisions(revisions, window_sec) do
    revisions
    |> Enum.reduce([], fn revision, groups ->
      case groups do
        [group | rest] ->
          if consolidate?(group, revision, window_sec) do
            [
              %{
                group
                | count: group.count + 1,
                  oldest_at: revision.committed_at
              }
              | rest
            ]
          else
            [new_group(revision) | groups]
          end

        [] ->
          [new_group(revision)]
      end
    end)
    |> Enum.reverse()
  end

  defp consolidate?(group, revision, window_sec) do
    group.summary == @auto_save_message and
      revision.summary == @auto_save_message and
      DateTime.diff(group.oldest_at, revision.committed_at, :second) <= window_sec
  end

  defp new_group(revision) do
    %{
      sha: revision.sha,
      committed_at: revision.committed_at,
      oldest_at: revision.committed_at,
      summary: revision.summary,
      count: 1
    }
  end

  defp split_frontmatter("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [frontmatter, body] -> {:ok, frontmatter, body}
      _ -> {:error, :invalid_frontmatter}
    end
  end

  defp split_frontmatter(_), do: {:error, :missing_frontmatter}

  defp frontmatter_field(frontmatter, field) do
    key = field <> ":"

    case Enum.find(String.split(frontmatter, "\n"), &String.starts_with?(&1, key)) do
      nil -> {:error, :field_not_found}
      line -> {:ok, String.trim_leading(line, key) |> String.trim()}
    end
  end
end
