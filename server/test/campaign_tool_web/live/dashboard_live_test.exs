defmodule CampaignToolWeb.DashboardLiveTest do
  use CampaignToolWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders dashboard with entity type links", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Campaign Tool"
    assert html =~ "npc"
    assert html =~ "session"
  end
end
