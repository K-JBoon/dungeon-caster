defmodule DungeonCasterWeb.EntityHelpersTest do
  use DungeonCaster.DataCase, async: true
  alias DungeonCasterWeb.EntityHelpers

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
  end
end
