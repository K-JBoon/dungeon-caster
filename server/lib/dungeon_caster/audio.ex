defmodule DungeonCaster.Audio do
  @moduledoc "Helpers for campaign-managed audio assets."

  @supported_extensions ~w(.mp3 .ogg .wav .m4a .aac .flac)

  def campaign_dir, do: Application.get_env(:dungeon_caster, :campaign_dir)

  def supported_extensions, do: @supported_extensions

  def upload_accept, do: Enum.join(@supported_extensions, ",")

  def asset_root, do: Path.join(campaign_dir(), "audio")

  def managed_asset_path(relative_path) do
    Path.join(asset_root(), normalize_relative_path(relative_path))
  end

  def asset_url(relative_path) do
    "/audio/" <> normalize_relative_path(relative_path)
  end

  def resolve_audio_file(relative_path) do
    normalized = normalize_relative_path(relative_path)

    if supported_audio_extension?(normalized) do
      resolved_safe_path(managed_asset_path(normalized))
    else
      :error
    end
  end

  def audio_file_available?(relative_path) do
    match?({:ok, _path}, resolve_audio_file(relative_path))
  end

  @doc "List ambient music tracks from audio/music/"
  def list_music do
    list_audio_files("music")
    |> Enum.map(fn relative_path ->
      %{path: relative_path, name: relative_path |> Path.basename() |> Path.rootname()}
    end)
  end

  @doc "List SFX files from audio/sfx/{section}/ subfolders."
  def list_sfx do
    list_audio_files("sfx")
    |> Enum.map(fn relative_path ->
      [_, section, file_name] = String.split(relative_path, "/", parts: 3)

      %{path: relative_path, name: Path.rootname(file_name), section: section}
    end)
  end

  @doc "Return the absolute filesystem path for a relative audio path like 'music/foo.mp3'"
  def file_path(relative_path), do: managed_asset_path(relative_path)

  defp list_audio_files(subdir) do
    dir = Path.join(asset_root(), subdir)

    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.flat_map(&list_entry(subdir, dir, &1))
        |> Enum.filter(&audio_file_available?/1)

      _ ->
        []
    end
  end

  defp list_entry(subdir, dir, entry) do
    entry_path = Path.join(dir, entry)

    cond do
      File.dir?(entry_path) ->
        case File.ls(entry_path) do
          {:ok, files} ->
            files
            |> Enum.sort()
            |> Enum.filter(&supported_audio_extension?/1)
            |> Enum.map(&Path.join([subdir, entry, &1]))

          _ ->
            []
        end

      supported_audio_extension?(entry) ->
        [Path.join(subdir, entry)]

      true ->
        []
    end
  end

  defp normalize_relative_path(path) do
    path
    |> to_string()
    |> String.trim_leading("/")
    |> String.trim_leading("audio/")
  end

  defp resolved_safe_path(path) do
    with {:ok, real_path} <- resolved_path(path),
         real_root <- Path.expand(asset_root()) do
      if String.starts_with?(real_path, real_root <> "/") and File.regular?(real_path) do
        {:ok, real_path}
      else
        :error
      end
    else
      _ -> :error
    end
  end

  defp resolved_path(path), do: resolve_full_path(Path.expand(path), 10)

  defp resolve_full_path(_path, 0), do: :error

  defp resolve_full_path(path, remaining_hops) do
    parts = Path.split(path)

    case parts do
      [root | rest] ->
        resolve_path_parts(root, rest, remaining_hops)

      _ ->
        :error
    end
  end

  defp resolve_path_parts(current, [], _remaining_hops), do: {:ok, current}

  defp resolve_path_parts(_current, _remaining_parts, 0), do: :error

  defp resolve_path_parts(current, [next | rest], remaining_hops) do
    candidate = Path.join(current, next)

    case File.lstat(candidate) do
      {:ok, %{type: :symlink}} ->
        case :file.read_link_all(String.to_charlist(candidate)) do
          {:ok, target} ->
            resolved_target =
              target
              |> List.to_string()
              |> expand_link_target(Path.dirname(candidate))

            [resolved_target | rest]
            |> Path.join()
            |> Path.expand()
            |> resolve_full_path(remaining_hops - 1)

          _ ->
            :error
        end

      {:ok, _} ->
        resolve_path_parts(candidate, rest, remaining_hops)

      _ ->
        :error
    end
  end

  defp expand_link_target(target, link_dir) do
    if Path.type(target) == :absolute do
      target
    else
      Path.expand(target, link_dir)
    end
  end

  defp supported_audio_extension?(path) do
    path
    |> Path.extname()
    |> String.downcase()
    |> then(&(&1 in @supported_extensions))
  end
end
