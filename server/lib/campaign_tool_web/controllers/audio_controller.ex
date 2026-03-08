defmodule CampaignToolWeb.AudioController do
  use CampaignToolWeb, :controller
  def stream(conn, _params), do: send_resp(conn, 404, "not implemented yet")
end
