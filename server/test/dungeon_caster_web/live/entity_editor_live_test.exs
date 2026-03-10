defmodule DungeonCasterWeb.EntityEditorLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities

  @test_file "/tmp/campaign_test/editor-test-npc.md"

  setup do
    File.mkdir_p!(Path.dirname(@test_file))
    File.write!(@test_file, "---\ntype: npc\nid: editor-test-npc\nname: Editor NPC\nstatus: alive\nrole: guard\ntags: []\nfaction_ids: []\n---\n\nOriginal body.")
    Entities.upsert_entity("npc", %{
      "id" => "editor-test-npc",
      "name" => "Editor NPC",
      "status" => "alive",
      "role" => "guard",
      "tags" => [],
      "faction_ids" => [],
      "body_raw" => "Original body.",
      "body_html" => "<p>Original body.</p>",
      "file_path" => @test_file
    })
    on_exit(fn -> File.rm(@test_file) end)
    :ok
  end

  test "renders file content in textarea", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/npc/editor-test-npc/edit")
    assert html =~ "Editor NPC"
    assert html =~ "Original body."
  end

  test "save event writes content to file", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/entities/npc/editor-test-npc/edit")
    view |> form("form", %{content: "---\ntype: npc\nid: editor-test-npc\nname: Editor NPC\nstatus: alive\nrole: guard\ntags: []\nfaction_ids: []\n---\n\nUpdated body."}) |> render_submit()
    assert File.read!(@test_file) =~ "Updated body."
  end
end
