defmodule CampaignToolWeb.ReceiverController do
  use CampaignToolWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
