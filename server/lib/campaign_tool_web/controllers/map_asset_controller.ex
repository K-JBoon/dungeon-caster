defmodule CampaignToolWeb.MapAssetController do
  use CampaignToolWeb, :controller

  def show(conn, %{"path" => path_parts}) do
    campaign_dir = Application.get_env(:campaign_tool, :campaign_dir) |> Path.expand()
    rel = Path.join(path_parts)

    if rel =~ ~r|^[a-zA-Z0-9_\-./]+$| do
      # Only serve files directly inside maps/assets/ — ignore subdirectory traversal
      filename = Path.basename(rel)
      file_path = Path.join([campaign_dir, "maps", "assets", filename])

      if File.exists?(file_path) do
        send_file(conn, 200, file_path)
      else
        send_resp(conn, 404, "Not found")
      end
    else
      send_resp(conn, 400, "Bad request")
    end
  end
end
