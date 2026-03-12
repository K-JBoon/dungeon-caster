defmodule DungeonCasterWeb.AudioController do
  use DungeonCasterWeb, :controller

  alias DungeonCaster.Audio

  def stream(conn, %{"path" => path_parts}) when is_list(path_parts) do
    relative_path = Enum.join(path_parts, "/")
    serve_audio(conn, relative_path)
  end

  def stream(conn, _params) do
    send_resp(conn, 400, "bad request")
  end

  defp serve_audio(conn, relative_path) do
    if relative_path =~ ~r/^[a-zA-Z0-9_\-\.\/]+$/ do
      case Audio.resolve_audio_file(relative_path) do
        {:ok, path} ->
        conn
        |> put_resp_content_type(content_type_for(path))
        |> send_file(200, path)

        :error ->
          send_resp(conn, 404, "not found")
      end
    else
      send_resp(conn, 400, "invalid path")
    end
  end

  defp content_type_for(path) do
    case path |> Path.extname() |> String.downcase() do
      ".mp3" -> "audio/mpeg"
      ".ogg" -> "audio/ogg"
      ".wav" -> "audio/wav"
      ".m4a" -> "audio/mp4"
      ".aac" -> "audio/aac"
      ".flac" -> "audio/flac"
      _ -> "application/octet-stream"
    end
  end
end
