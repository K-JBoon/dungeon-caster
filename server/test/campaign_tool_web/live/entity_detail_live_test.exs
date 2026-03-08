defmodule CampaignToolWeb.EntityDetailLiveTest do
  use CampaignToolWeb.ConnCase
  import Phoenix.LiveViewTest
  alias CampaignTool.Entities

  setup do
    Entities.upsert_entity("npc", %{
      "id" => "detail-test-npc",
      "name" => "Detail Test NPC",
      "status" => "alive",
      "role" => "villain",
      "tags" => ["evil"],
      "faction_ids" => [],
      "body_raw" => "This NPC is very dangerous.",
      "body_html" => "<p>This NPC is very dangerous.</p>",
      "file_path" => "/tmp/detail-test-npc.md"
    })
    :ok
  end

  test "renders entity name and body", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/npc/detail-test-npc")
    assert html =~ "Detail Test NPC"
    assert html =~ "very dangerous"
  end

  test "live-updates when PubSub broadcasts :updated", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/entities/npc/detail-test-npc")
    # Update the entity in DB then broadcast
    Entities.upsert_entity("npc", %{
      "id" => "detail-test-npc",
      "name" => "Updated NPC Name",
      "status" => "alive",
      "role" => "villain",
      "tags" => [],
      "faction_ids" => [],
      "body_raw" => "Updated body.",
      "body_html" => "<p>Updated body.</p>",
      "file_path" => "/tmp/detail-test-npc.md"
    })
    Phoenix.PubSub.broadcast(CampaignTool.PubSub, "entities:npc", {:updated, "detail-test-npc"})
    assert render(view) =~ "Updated NPC Name"
  end

  test "has an edit link", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/npc/detail-test-npc")
    assert html =~ "/entities/npc/detail-test-npc/edit"
  end
end
