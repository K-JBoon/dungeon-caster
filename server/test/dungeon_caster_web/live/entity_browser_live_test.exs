defmodule DungeonCasterWeb.EntityBrowserLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities

  setup do
    Entities.upsert_entity("npc", %{
      "id" => "browser-test-npc",
      "name" => "Browser Test NPC",
      "status" => "alive",
      "role" => "guard",
      "tags" => [],
      "faction_ids" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/browser-test-npc.md"
    })
    :ok
  end

  test "renders entity list for type", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/npc")
    assert html =~ "Browser Test NPC"
  end

  test "live-updates when entity is upserted via PubSub", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/entities/npc")
    Entities.upsert_entity("npc", %{
      "id" => "pubsub-test-npc",
      "name" => "PubSub NPC",
      "status" => "alive",
      "role" => "guard",
      "tags" => [],
      "faction_ids" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/pubsub-test-npc.md"
    })
    Phoenix.PubSub.broadcast(DungeonCaster.PubSub, "entities:npc", {:updated, "pubsub-test-npc"})
    assert render(view) =~ "PubSub NPC"
  end
end
