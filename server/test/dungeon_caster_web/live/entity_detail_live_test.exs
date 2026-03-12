defmodule DungeonCasterWeb.EntityDetailLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities

  setup do
    previous_campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir)

    campaign_dir =
      Path.join(System.tmp_dir!(), "entity-detail-live-#{System.unique_integer([:positive])}")

    File.rm_rf!(campaign_dir)
    File.mkdir_p!(Path.join(campaign_dir, "audio/assets"))
    File.write!(Path.join(campaign_dir, "audio/assets/available-track.mp3"), "mp3")
    Application.put_env(:dungeon_caster, :campaign_dir, campaign_dir)

    on_exit(fn ->
      File.rm_rf!(campaign_dir)

      if previous_campaign_dir do
        Application.put_env(:dungeon_caster, :campaign_dir, previous_campaign_dir)
      else
        Application.delete_env(:dungeon_caster, :campaign_dir)
      end
    end)

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

    assert {:ok, _audio} =
             Entities.upsert_entity("audio", %{
               "id" => "detail-test-audio",
               "name" => "Detail Test Audio",
               "category" => "ambient",
               "asset_path" => "audio/assets/available-track.mp3",
               "body_raw" => "Play during downtime.",
               "body_html" => "<p>Play during downtime.</p>",
               "file_path" => Path.join(campaign_dir, "audio/detail-test-audio.md")
             })

    assert {:ok, _missing_audio} =
             Entities.upsert_entity("audio", %{
               "id" => "detail-missing-audio",
               "name" => "Missing Audio",
               "category" => "sfx",
               "asset_path" => "audio/assets/missing-track.mp3",
               "body_raw" => "",
               "body_html" => "",
               "file_path" => Path.join(campaign_dir, "audio/detail-missing-audio.md")
             })

    {:ok, campaign_dir: campaign_dir}
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

    Phoenix.PubSub.broadcast(DungeonCaster.PubSub, "entities:npc", {:updated, "detail-test-npc"})
    assert render(view) =~ "Updated NPC Name"
  end

  test "has an edit link", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/npc/detail-test-npc")
    assert html =~ "/entities/npc/detail-test-npc/edit"
  end

  test "renders audio metadata when the asset is available", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/audio/detail-test-audio")

    assert html =~ "Detail Test Audio"
    assert html =~ "ambient"
    assert html =~ "audio/assets/available-track.mp3"
    refute html =~ "Audio file missing"
  end

  test "renders an audio missing-file warning when the asset path is unavailable", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/audio/detail-missing-audio")

    assert html =~ "Missing Audio"
    assert html =~ "sfx"
    assert html =~ "audio/assets/missing-track.mp3"
    assert html =~ "Audio file missing"
  end
end
