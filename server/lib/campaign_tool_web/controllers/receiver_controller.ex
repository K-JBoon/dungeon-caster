defmodule CampaignToolWeb.ReceiverController do
  use CampaignToolWeb, :controller
  def index(conn, _params), do: send_resp(conn, 200, "receiver placeholder")
end
