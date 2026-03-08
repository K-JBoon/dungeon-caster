defmodule CampaignToolWeb.Plugs.CampaignStatic do
  @moduledoc "Serves static files from the campaign directory's maps/assets/ folder."
  @behaviour Plug
  import Plug.Conn

  def init(opts), do: opts

  def call(%{path_info: ["maps", "assets" | rest]} = conn, _opts) do
    campaign_dir = Application.get_env(:campaign_tool, :campaign_dir)
    file_path = Path.join([campaign_dir, "maps", "assets"] ++ rest)

    if File.regular?(file_path) do
      conn
      |> put_resp_content_type(content_type(file_path))
      |> send_file(200, file_path)
      |> halt()
    else
      conn
    end
  end

  def call(conn, _opts), do: conn

  defp content_type(path) do
    case Path.extname(path) do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end
end
