defmodule DungeonCasterWeb.EntityHelpersTest do
  use DungeonCaster.DataCase, async: false
  alias DungeonCaster.Entities
  alias DungeonCasterWeb.EntityHelpers

  @audio_attrs %{
    "id" => "tavern-theme",
    "name" => "Tavern Theme",
    "category" => "music",
    "asset_path" => "audio/music/tavern-theme.mp3",
    "tags" => ["inn", "calm"],
    "body_raw" => "Loop for downtime scenes",
    "body_html" => "<p>Loop for downtime scenes</p>",
    "file_path" => "audio/tavern-theme.md"
  }

  setup do
    previous_campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir)

    campaign_dir =
      Path.join(System.tmp_dir!(), "entity-helpers-#{System.unique_integer([:positive])}")

    File.rm_rf!(campaign_dir)
    File.mkdir_p!(Path.join(campaign_dir, "audio/music"))
    Application.put_env(:dungeon_caster, :campaign_dir, campaign_dir)

    on_exit(fn ->
      File.rm_rf!(campaign_dir)

      if previous_campaign_dir do
        Application.put_env(:dungeon_caster, :campaign_dir, previous_campaign_dir)
      else
        Application.delete_env(:dungeon_caster, :campaign_dir)
      end
    end)

    {:ok, campaign_dir: campaign_dir}
  end

  describe "load_entity_from_ref/1" do
    test "returns nil for malformed ref" do
      assert EntityHelpers.load_entity_from_ref("badref") == nil
    end

    test "returns nil for unknown entity" do
      assert EntityHelpers.load_entity_from_ref("npc:does-not-exist") == nil
    end

    test "returns nil for nil input" do
      assert EntityHelpers.load_entity_from_ref(nil) == nil
    end
  end

  describe "search_entities/1" do
    test "returns empty list for short query" do
      assert EntityHelpers.search_entities("a") == []
    end

    test "returns empty list for empty string" do
      assert EntityHelpers.search_entities("") == []
    end

    test "returns empty list for nil" do
      assert EntityHelpers.search_entities(nil) == []
    end
  end

  describe "entity_popover_data/1" do
    test "returns :error for unknown ref" do
      assert EntityHelpers.entity_popover_data("npc:does-not-exist") == :error
    end

    test "returns :error for malformed ref" do
      assert EntityHelpers.entity_popover_data("bad") == :error
    end

    test "returns playback metadata for playable audio entities", %{campaign_dir: campaign_dir} do
      File.write!(Path.join(campaign_dir, "audio/music/tavern-theme.mp3"), "fake mp3 data")
      assert {:ok, audio} = Entities.upsert_entity("audio", @audio_attrs)

      assert {:ok,
              %{
                type: "audio",
                playable: true,
                category: "music",
                asset_path: "music/tavern-theme.mp3",
                html: html
              }} = EntityHelpers.entity_popover_data("audio:#{audio.id}")

      assert html =~ ~s(entity-popover-audio-action)
      assert html =~ ~s(entity-popover-audio-play)
      assert html =~ ~s(phx-click="play_audio_entity")
      assert html =~ ~s(phx-value-asset_path="music/tavern-theme.mp3")
      assert html =~ ~s(phx-value-category="music")
    end
  end

  describe "entity_type_icon/1" do
    test "returns the sidebar icon for known entity types" do
      assert EntityHelpers.entity_type_icon("npc") == "hero-user-group"
      assert EntityHelpers.entity_type_icon("location") == "hero-map-pin"
      assert EntityHelpers.entity_type_icon("faction") == "hero-shield-check"
      assert EntityHelpers.entity_type_icon("stat-block") == "hero-book-open"
      assert EntityHelpers.entity_type_icon("map") == "hero-map"
      assert EntityHelpers.entity_type_icon("audio") == "hero-speaker-wave"
    end

    test "falls back to a neutral icon for unknown types" do
      assert EntityHelpers.entity_type_icon("mystery") == "hero-link"
    end
  end
end
