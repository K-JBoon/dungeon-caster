defmodule DungeonCasterWeb.DashboardLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities

  setup do
    assert {:ok, _audio} =
             Entities.upsert_entity("audio", %{
               "id" => "dashboard-test-audio",
               "name" => "Dashboard Test Audio",
               "category" => "ambient",
               "asset_path" => "audio/assets/dashboard-test.mp3",
               "body_raw" => "",
               "body_html" => "",
               "file_path" => "/tmp/dashboard-test-audio.md"
             })

    :ok
  end

  test "renders dashboard with entity type links", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Dungeon Caster"
    assert html =~ "npc"
    assert html =~ "session"
    assert html =~ "Audio"
    assert html =~ "/entities/audio"
  end
end
