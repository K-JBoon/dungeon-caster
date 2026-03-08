defmodule CampaignTool.Audio do
  @moduledoc "Lists audio files from the campaign directory."

  def campaign_dir, do: Application.get_env(:campaign_tool, :campaign_dir)

  @doc "List ambient music tracks from audio/music/"
  def list_music do
    dir = Path.join(campaign_dir(), "audio/music")
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".mp3"))
        |> Enum.sort()
        |> Enum.map(fn f -> %{path: "music/#{f}", name: Path.rootname(f)} end)
      _ ->
        []
    end
  end

  @doc "List SFX files from audio/sfx/{section}/ subfolders."
  def list_sfx do
    dir = Path.join(campaign_dir(), "audio/sfx")
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          subdir = Path.join(dir, entry)
          if File.dir?(subdir) do
            case File.ls(subdir) do
              {:ok, files} ->
                files
                |> Enum.filter(&String.ends_with?(&1, ".mp3"))
                |> Enum.sort()
                |> Enum.map(fn f ->
                  %{path: "sfx/#{entry}/#{f}", name: Path.rootname(f), section: entry}
                end)
              _ -> []
            end
          else
            []
          end
        end)
      _ ->
        []
    end
  end

  @doc "Return the absolute filesystem path for a relative audio path like 'music/foo.mp3'"
  def file_path(relative) do
    Path.join([campaign_dir(), "audio", relative])
  end
end
