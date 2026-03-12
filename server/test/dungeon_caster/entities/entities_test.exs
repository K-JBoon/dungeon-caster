defmodule DungeonCaster.EntitiesTest do
  use DungeonCaster.DataCase, async: false

  alias DungeonCaster.Entities

  @npc_attrs %{
    "id" => "gandalf",
    "name" => "Gandalf",
    "status" => "alive",
    "role" => "wizard"
  }

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

  describe "upsert_entity/2" do
    test "inserts a new entity" do
      assert {:ok, npc} = Entities.upsert_entity("npc", @npc_attrs)
      assert npc.id == "gandalf"
      assert npc.name == "Gandalf"
      assert npc.status == "alive"
      assert npc.role == "wizard"
    end

    test "upsert is idempotent — second call updates without error" do
      assert {:ok, _} = Entities.upsert_entity("npc", @npc_attrs)
      updated = Map.put(@npc_attrs, "status", "dead")
      assert {:ok, npc} = Entities.upsert_entity("npc", updated)
      assert npc.status == "dead"
    end

    test "inserts an audio entity" do
      assert {:ok, audio} = Entities.upsert_entity("audio", @audio_attrs)
      assert audio.id == "tavern-theme"
      assert audio.name == "Tavern Theme"
      assert audio.category == "music"
      assert audio.asset_path == "audio/music/tavern-theme.mp3"
      assert audio.tags == ["inn", "calm"]
      assert audio.body_raw == "Loop for downtime scenes"
      assert audio.body_html == "<p>Loop for downtime scenes</p>"
      assert audio.file_path == "audio/tavern-theme.md"
    end

    test "updates an existing audio entity without creating a duplicate" do
      assert {:ok, _audio} = Entities.upsert_entity("audio", @audio_attrs)

      updated_attrs =
        @audio_attrs
        |> Map.put("name", "Tavern Theme (Night)")
        |> Map.put("tags", ["inn", "night"])
        |> Map.put("body_raw", "Use after sunset")

      assert {:ok, audio} = Entities.upsert_entity("audio", updated_attrs)
      assert audio.name == "Tavern Theme (Night)"
      assert audio.tags == ["inn", "night"]
      assert audio.body_raw == "Use after sunset"

      persisted = Entities.get_entity!("audio", "tavern-theme")
      assert persisted.name == "Tavern Theme (Night)"
      assert persisted.tags == ["inn", "night"]
      assert persisted.body_raw == "Use after sunset"

      audio_entities = Entities.list_entities("audio")
      assert length(audio_entities) == 1
    end
  end

  describe "list_entities/2" do
    test "returns all entities of a type" do
      {:ok, _} = Entities.upsert_entity("npc", @npc_attrs)
      {:ok, _} = Entities.upsert_entity("npc", Map.put(@npc_attrs, "id", "saruman"))

      npcs = Entities.list_entities("npc")
      assert length(npcs) == 2
    end

    test "returns only audio entities for the audio type" do
      {:ok, _} = Entities.upsert_entity("audio", @audio_attrs)

      second_audio =
        @audio_attrs
        |> Map.put("id", "battle-drums")
        |> Map.put("name", "Battle Drums")
        |> Map.put("category", "sfx")
        |> Map.put("asset_path", "audio/sfx/battle-drums.mp3")

      {:ok, _} = Entities.upsert_entity("audio", second_audio)
      {:ok, _} = Entities.upsert_entity("npc", @npc_attrs)

      audio_entities = Entities.list_entities("audio")

      assert Enum.map(audio_entities, & &1.id) |> Enum.sort() == ["battle-drums", "tavern-theme"]
      assert Enum.all?(audio_entities, &match?(%{category: _}, &1))
    end

    test "ignores status filtering for audio entities" do
      {:ok, _} = Entities.upsert_entity("audio", @audio_attrs)

      second_audio =
        @audio_attrs
        |> Map.put("id", "battle-drums")
        |> Map.put("name", "Battle Drums")
        |> Map.put("category", "sfx")
        |> Map.put("asset_path", "audio/sfx/battle-drums.mp3")

      {:ok, _} = Entities.upsert_entity("audio", second_audio)

      audio_entities = Entities.list_entities("audio", status: "alive")

      assert Enum.map(audio_entities, & &1.id) |> Enum.sort() == ["battle-drums", "tavern-theme"]
    end
  end

  describe "delete_entity/2" do
    test "deletes an existing entity and returns :ok" do
      {:ok, _} = Entities.upsert_entity("npc", @npc_attrs)
      assert :ok = Entities.delete_entity("npc", "gandalf")
      assert Entities.get_entity("npc", "gandalf") == nil
    end

    test "deletes an audio entity and returns :ok" do
      {:ok, _} = Entities.upsert_entity("audio", @audio_attrs)

      assert :ok = Entities.delete_entity("audio", "tavern-theme")
      assert Entities.get_entity("audio", "tavern-theme") == nil
    end
  end
end
