defmodule CampaignTool.EntitiesTest do
  use CampaignTool.DataCase, async: false

  alias CampaignTool.Entities

  @npc_attrs %{
    "id" => "gandalf",
    "name" => "Gandalf",
    "status" => "alive",
    "role" => "wizard"
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
  end

  describe "list_entities/2" do
    test "returns all entities of a type" do
      {:ok, _} = Entities.upsert_entity("npc", @npc_attrs)
      {:ok, _} = Entities.upsert_entity("npc", Map.put(@npc_attrs, "id", "saruman"))

      npcs = Entities.list_entities("npc")
      assert length(npcs) == 2
    end
  end

  describe "delete_entity/2" do
    test "deletes an existing entity and returns :ok" do
      {:ok, _} = Entities.upsert_entity("npc", @npc_attrs)
      assert :ok = Entities.delete_entity("npc", "gandalf")
      assert Entities.get_entity("npc", "gandalf") == nil
    end
  end
end
