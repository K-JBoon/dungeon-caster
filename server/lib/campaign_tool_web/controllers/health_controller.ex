defmodule CampaignToolWeb.HealthController do
  use CampaignToolWeb, :controller
  def index(conn, _params), do: send_resp(conn, 200, "ok")
end
