defmodule DungeonCasterWeb.SessionRunnerLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.{Entities, Session.Server}

  @test_file "/tmp/run-session-01.md"
  @scenes_json Jason.encode!([
                 %{
                   "id" => "s1",
                   "title" => "Opening",
                   "notes" => "They arrive.",
                   "entity_ids" => []
                 }
               ])

  setup do
    campaign_dir = Application.fetch_env!(:dungeon_caster, :campaign_dir)
    audio_root = Path.join(campaign_dir, "audio")

    File.rm_rf!(audio_root)
    File.mkdir_p!(Path.join(audio_root, "music"))
    File.mkdir_p!(Path.join(audio_root, "sfx"))
    File.write!(Path.join(audio_root, "music/a-lanterns-low.mp3"), "ambient-a")
    File.write!(Path.join(audio_root, "music/prefixed-echo.mp3"), "ambient-p")
    File.write!(Path.join(audio_root, "music/twin-echo-a.mp3"), "ambient-ta")
    File.write!(Path.join(audio_root, "music/twin-echo-z.mp3"), "ambient-tz")
    File.write!(Path.join(audio_root, "music/zebra-winds.mp3"), "ambient-z")
    File.write!(Path.join(audio_root, "sfx/creak-door.mp3"), "sfx-c")
    File.write!(Path.join(audio_root, "sfx/storm-bell.mp3"), "sfx-s")

    File.write!(
      @test_file,
      "---\ntype: session\nid: run-session-01\ntitle: The Heist\nsession_number: 1\nstatus: planned\n---\n"
    )

    Entities.upsert_entity("session", %{
      "id" => "run-session-01",
      "title" => "The Heist",
      "session_number" => 1,
      "status" => "planned",
      "scenes" => @scenes_json,
      "tags" => [],
      "npc_ids" => [],
      "location_ids" => [],
      "map_ids" => [],
      "stat_block_ids" => [],
      "faction_ids" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => @test_file
    })

    Entities.upsert_entity("audio", %{
      "id" => "prefixed-echo",
      "name" => "Prefixed Echo",
      "category" => "ambient",
      "asset_path" => "audio/music/prefixed-echo.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/prefixed-echo.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "twin-echo-b",
      "name" => "Twin Echo",
      "category" => "ambient",
      "asset_path" => "music/twin-echo-a.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/twin-echo-b.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "twin-echo-a",
      "name" => "Twin Echo",
      "category" => "ambient",
      "asset_path" => "music/twin-echo-z.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/twin-echo-a.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "zebra-winds",
      "name" => "Zebra Winds",
      "category" => "ambient",
      "asset_path" => "music/zebra-winds.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/zebra-winds.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "a-lanterns-low",
      "name" => "A Lanterns Low",
      "category" => "music",
      "asset_path" => "music/a-lanterns-low.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/a-lanterns-low.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "storm-bell",
      "name" => "Storm Bell",
      "category" => "sfx",
      "asset_path" => "sfx/storm-bell.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/storm-bell.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "creak-door",
      "name" => "Creak Door",
      "category" => "sfx",
      "asset_path" => "sfx/creak-door.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/creak-door.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "missing-track",
      "name" => "Missing Track",
      "category" => "ambient",
      "asset_path" => "music/missing-track.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/missing-track.md"
    })

    {:ok, _} = Server.start_link("run-session-01")

    on_exit(fn ->
      File.rm_rf!(audio_root)

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
    assert html =~ "Audio"
  end

  test "plan mode shows scenes", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sessions/run-session-01/run")
    assert html =~ "Opening"
  end

  test "audio mode treats legacy music entities as ambient audio", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/run-session-01/run")

    html =
      view
      |> element("button[phx-value-mode='audio']")
      |> render_click()

    assert html =~ "Ambient"
    assert html =~ "A Lanterns Low"
    assert html =~ "Prefixed Echo"
    assert html =~ "Twin Echo"
    assert html =~ "Zebra Winds"
    assert html =~ "SFX"
    assert html =~ "Creak Door"
    assert html =~ "Storm Bell"
    refute html =~ "Missing Track"

    assert html_index(html, "A Lanterns Low") < html_index(html, "Prefixed Echo")
    assert html_index(html, "Prefixed Echo") < html_index(html, "Zebra Winds")
    assert html_index(html, "Creak Door") < html_index(html, "Storm Bell")
  end

  test "audio mode uses a stable secondary key when names match", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/run-session-01/run")

    html =
      view
      |> element("button[phx-value-mode='audio']")
      |> render_click()

    assert html =~ ~s(phx-value-path="music/twin-echo-a.mp3")
    assert html =~ ~s(phx-value-path="music/twin-echo-z.mp3")

    assert html_index(html, ~s(phx-value-path="music/twin-echo-a.mp3")) <
             html_index(html, ~s(phx-value-path="music/twin-echo-z.mp3"))
  end

  test "audio mode normalizes prefixed asset paths for playback", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/run-session-01/run")

    html =
      view
      |> element("button[phx-value-mode='audio']")
      |> render_click()

    assert html =~ ~s(phx-value-path="music/prefixed-echo.mp3")
    refute html =~ ~s(phx-value-path="audio/music/prefixed-echo.mp3")

    view
    |> element("button[phx-click='play_ambient'][phx-value-path='music/prefixed-echo.mp3']")
    |> render_click()

    assert Server.get_state("run-session-01").audio_state.ambient == "music/prefixed-echo.mp3"
  end

  test "play_audio_entity routes normalized audio popover playback by category", %{conn: conn} do
    Phoenix.PubSub.subscribe(DungeonCaster.PubSub, "session:live:run-session-01")
    {:ok, view, _html} = live(conn, "/sessions/run-session-01/run")

    render_hook(view, "play_audio_entity", %{
      "asset_path" => "audio/music/prefixed-echo.mp3",
      "category" => "music"
    })

    assert Server.get_state("run-session-01").audio_state.ambient == "music/prefixed-echo.mp3"
    assert_receive {"audio_play", %{path: "music/prefixed-echo.mp3", type: "ambient"}}

    render_hook(view, "play_audio_entity", %{
      "asset_path" => "audio/sfx/storm-bell.mp3",
      "category" => "sfx"
    })

    assert_receive {"audio_play", %{path: "sfx/storm-bell.mp3", type: "sfx"}}
  end

  defp html_index(html, text) do
    {index, _len} = :binary.match(html, text)
    index
  end
end
