defmodule CampaignToolWeb.PageController do
  use CampaignToolWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
