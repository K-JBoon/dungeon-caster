defmodule DungeonCasterWeb.MapViewerLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities

  setup do
    Entities.upsert_entity("map", %{
      "id" => "test-map",
      "name" => "Test Dungeon",
      "map_type" => "dungeon",
      "asset_path" => "maps/assets/test-dungeon.png",
      "tags" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/test-map.md"
    })

    :ok
  end

  test "renders map name and image", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/maps/test-map")
    assert html =~ "Test Dungeon"
    assert html =~ "test-dungeon.png"
  end
end
