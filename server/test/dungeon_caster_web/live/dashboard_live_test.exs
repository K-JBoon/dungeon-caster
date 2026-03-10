defmodule DungeonCasterWeb.DashboardLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest

  test "renders dashboard with entity type links", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Dungeon Caster"
    assert html =~ "npc"
    assert html =~ "session"
  end
end
