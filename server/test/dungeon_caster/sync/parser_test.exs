defmodule DungeonCaster.Sync.ParserTest do
  use ExUnit.Case
  alias DungeonCaster.Sync.Parser

  @fixtures Path.expand("../../fixtures", __DIR__)

  test "parses valid NPC file" do
    path = Path.join(@fixtures, "npcs/elara-moonwhisper.md")
    assert {:ok, "npc", data} = Parser.parse_file(path)
    assert data["id"] == "elara-moonwhisper"
    assert data["name"] == "Elara Moonwhisper"
    assert data["status"] == "alive"
    assert data["faction_ids"] == ["crimson-accord"]
    assert data["body_html"] =~ "Ironveil Mage Council"
    assert is_binary(data["body_raw"])
    assert is_binary(data["body_html"])
    assert data["file_path"] == path
  end

  test "parses stat-block file" do
    path = Path.join(@fixtures, "stat-blocks/shadow-goblin.md")
    assert {:ok, "stat-block", data} = Parser.parse_file(path)
    assert data["id"] == "shadow-goblin"
    assert data["name"] == "Shadow Goblin"
    assert is_binary(data["body_raw"])
    assert is_binary(data["body_html"])
  end

  test "parses session file" do
    path = Path.join(@fixtures, "sessions/session-01.md")
    assert {:ok, "session", data} = Parser.parse_file(path)
    assert data["title"] == "The Heist"
    assert data["session_number"] == 1
  end

  test "returns error for missing file" do
    assert {:error, _} = Parser.parse_file("/nonexistent/path.md")
  end

  test "returns error when type mismatches directory" do
    # NPC file placed in a locations directory should fail type validation
    src = Path.join(@fixtures, "npcs/elara-moonwhisper.md")
    tmp_dir = Path.join(System.tmp_dir!(), "locations")
    File.mkdir_p!(tmp_dir)
    tmp = Path.join(tmp_dir, "elara-moonwhisper.md")
    File.copy!(src, tmp)
    assert {:error, _} = Parser.parse_file(tmp)
    File.rm!(tmp)
  end

  test "returns error for file without frontmatter" do
    tmp = Path.join(System.tmp_dir!(), "no-frontmatter.md")
    File.write!(tmp, "Just some text without frontmatter")
    assert {:error, _} = Parser.parse_file(tmp)
    File.rm!(tmp)
  end
end
