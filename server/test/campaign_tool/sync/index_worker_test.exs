defmodule CampaignTool.Sync.IndexWorkerTest do
  use CampaignTool.DataCase
  alias CampaignTool.Sync.IndexWorker
  alias CampaignTool.Entities

  @fixtures Path.expand("../../fixtures", __DIR__)

  test "index_file/1 indexes a valid NPC file into the DB" do
    path = Path.join(@fixtures, "npcs/elara-moonwhisper.md")
    assert :ok = IndexWorker.index_file(path)
    entity = Entities.get_entity!("npc", "elara-moonwhisper")
    assert entity.name == "Elara Moonwhisper"
    assert entity.tags == ["mage"]
  end

  test "index_file/1 returns :ok for unparseable file (logs warning, no crash)" do
    tmp = Path.join(System.tmp_dir!(), "bad.md")
    File.write!(tmp, "no frontmatter here")
    assert :ok = IndexWorker.index_file(tmp)
    File.rm!(tmp)
  end
end
