defmodule CampaignToolWeb.AudioController do
  use CampaignToolWeb, :controller
  alias CampaignTool.Audio

  def stream(conn, %{"path" => path_parts}) when is_list(path_parts) do
    relative = Enum.join(path_parts, "/")
    serve_audio(conn, relative)
  end

  def stream(conn, _params) do
    send_resp(conn, 400, "bad request")
  end

  defp serve_audio(conn, relative) do
    # Sanitize: only allow alphanumeric, dashes, underscores, dots, slashes
    if relative =~ ~r/^[a-zA-Z0-9_\-\.\/]+$/ do
      full_path = Audio.file_path(relative)
      expanded = Path.expand(full_path)
      base = Path.expand(Path.join(Audio.campaign_dir(), "audio"))

      if String.starts_with?(expanded, base <> "/") and File.regular?(expanded) do
        conn
        |> put_resp_content_type("audio/mpeg")
        |> send_file(200, expanded)
      else
        send_resp(conn, 404, "not found")
      end
    else
      send_resp(conn, 400, "invalid path")
    end
  end
end
