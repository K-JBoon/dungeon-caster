defmodule DungeonCasterWeb.SessionRunnerLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.{Entities, Session.Server}

  @test_file "/tmp/run-session-01.md"
  @scenes_json Jason.encode!([%{"id" => "s1", "title" => "Opening", "notes" => "They arrive.", "entity_ids" => []}])

  setup do
    File.write!(@test_file, "---\ntype: session\nid: run-session-01\ntitle: The Heist\nsession_number: 1\nstatus: planned\n---\n")
    Entities.upsert_entity("session", %{
      "id" => "run-session-01", "title" => "The Heist",
      "session_number" => 1, "status" => "planned",
      "scenes" => @scenes_json,
      "tags" => [], "npc_ids" => [], "location_ids" => [], "map_ids" => [],
      "stat_block_ids" => [], "faction_ids" => [],
      "body_raw" => "", "body_html" => "", "file_path" => @test_file
    })
    {:ok, _} = Server.start_link("run-session-01")
    on_exit(fn ->
      try do
        Server.stop("run-session-01")
      catch
        :exit, _ -> :ok
      end
    end)
    :ok
  end

  test "renders session runner with modes", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sessions/run-session-01/run")
    assert html =~ "Plan"
    assert html =~ "Map"
    assert html =~ "Combat"
    assert html =~ "Audio"
  end

  test "plan mode shows scenes", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sessions/run-session-01/run")
    assert html =~ "Opening"
  end
end
