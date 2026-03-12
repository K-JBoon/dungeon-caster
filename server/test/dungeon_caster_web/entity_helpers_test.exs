defmodule DungeonCasterWeb.EntityHelpersTest do
  use DungeonCaster.DataCase, async: true
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

    test "returns category and asset_path for audio entities" do
      assert {:ok, audio} = Entities.upsert_entity("audio", @audio_attrs)

      assert {:ok,
              %{
                type: "audio",
                category: "music",
                asset_path: "audio/music/tavern-theme.mp3"
              }} = EntityHelpers.entity_popover_data("audio:#{audio.id}")
    end
  end
end
