defmodule DungeonCasterWeb.SessionPlannerLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities

  @test_file "/tmp/campaign_test/session-planner-01.md"

  setup do
    File.mkdir_p!("/tmp/campaign_test")
    File.write!(@test_file, "---\ntype: session\nid: session-planner-01\ntitle: The Heist\nsession_number: 1\nstatus: planned\nscenes: \"[]\"\ntags: []\nnpc_ids: []\nlocation_ids: []\nmap_ids: []\nstat_block_ids: []\nfaction_ids: []\n---\n\nSession notes.")
    Entities.upsert_entity("session", %{
      "id" => "session-planner-01",
      "title" => "The Heist",
      "session_number" => 1,
      "status" => "planned",
      "scenes" => "[]",
      "tags" => [],
      "npc_ids" => [],
      "location_ids" => [],
      "map_ids" => [],
      "stat_block_ids" => [],
      "faction_ids" => [],
      "body_raw" => "Session notes.",
      "body_html" => "<p>Session notes.</p>",
      "file_path" => @test_file
    })
    on_exit(fn -> File.rm(@test_file) end)
    :ok
  end

  test "renders session title", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sessions/session-planner-01/plan")
    assert html =~ "The Heist"
  end

  test "add scene button adds a new scene", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/session-planner-01/plan")
    html = view |> element("button", "Add Scene") |> render_click()
    assert html =~ "New Scene"
  end

  test "Go Live button starts session and redirects to runner", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/session-planner-01/plan")
    assert {:error, {:live_redirect, %{to: path}}} =
      view |> element("button", "Go Live") |> render_click()
    assert path == "/sessions/session-planner-01/run"
    # Clean up
    try do
      DungeonCaster.Session.Server.stop("session-planner-01")
    catch
      :exit, _ -> :ok
    end
  end

  test "linked entities sidebar shows entity from body_raw ref", %{conn: conn} do
    # Create a location entity
    {:ok, _} = Entities.upsert_entity("location", %{
      "id" => "test-city",
      "name" => "Test City",
      "location_type" => "city",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/test-city.md",
      "tags" => [],
      "faction_ids" => []
    })

    # Create session with a body ref to that location
    {:ok, _} = Entities.upsert_entity("session", %{
      "id" => "test-sess",
      "title" => "Test Session",
      "session_number" => 1,
      "status" => "planned",
      "body_raw" => "Visit ~[Test City]{location:test-city} tonight.",
      "body_html" => "",
      "file_path" => "/tmp/test-sess.md",
      "tags" => [],
      "npc_ids" => [],
      "location_ids" => [],
      "map_ids" => [],
      "stat_block_ids" => [],
      "faction_ids" => []
    })

    {:ok, _view, html} = live(conn, "/sessions/test-sess/plan")
    assert html =~ "Test City"
  end
end
