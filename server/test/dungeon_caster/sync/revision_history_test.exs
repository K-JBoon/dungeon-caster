defmodule DungeonCaster.Sync.RevisionHistoryTest do
  use ExUnit.Case

  alias DungeonCaster.Sync.RevisionHistory

  setup do
    tmp = System.tmp_dir!() |> Path.join("campaign_revision_test_#{:rand.uniform(999_999)}")
    File.mkdir_p!(tmp)
    System.cmd("git", ["init"], cd: tmp)
    System.cmd("git", ["config", "user.email", "test@test.com"], cd: tmp)
    System.cmd("git", ["config", "user.name", "Test"], cd: tmp)

    previous_campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir)
    Application.put_env(:dungeon_caster, :campaign_dir, tmp)

    on_exit(fn ->
      if previous_campaign_dir do
        Application.put_env(:dungeon_caster, :campaign_dir, previous_campaign_dir)
      else
        Application.delete_env(:dungeon_caster, :campaign_dir)
      end

      File.rm_rf!(tmp)
    end)

    {:ok, tmp: tmp}
  end

  test "consolidates nearby auto-save commits for a file", %{tmp: tmp} do
    path = Path.join(tmp, "npcs/history-test.md")
    File.mkdir_p!(Path.dirname(path))

    write_commit(
      tmp,
      path,
      "---\ntype: npc\nid: history-test\n---\nfirst\n",
      "Dungeon Caster auto-save",
      "2026-03-10T10:00:00Z"
    )

    write_commit(
      tmp,
      path,
      "---\ntype: npc\nid: history-test\n---\nsecond\n",
      "Dungeon Caster auto-save",
      "2026-03-10T10:04:00Z"
    )

    write_commit(
      tmp,
      path,
      "---\ntype: npc\nid: history-test\n---\nthird\n",
      "Manual checkpoint",
      "2026-03-10T11:00:00Z"
    )

    assert {:ok, revisions} = RevisionHistory.list_file_revisions(path)
    assert length(revisions) == 2

    [latest, older] = revisions
    assert latest.summary == "Manual checkpoint"
    assert latest.count == 1
    assert older.summary == "Dungeon Caster auto-save"
    assert older.count == 2
  end

  test "extracts editor-specific content from committed files" do
    content = """
    ---
    type: session
    id: session-1
    scenes: [{"id":"scene-1","notes":"Scene one"},{"id":"scene-2","notes":"Scene two"}]
    ---
    Session body
    """

    assert RevisionHistory.extract_editor_content(content, :raw) == content
    assert RevisionHistory.extract_editor_content(content, :body) == "Session body\n"

    assert RevisionHistory.extract_editor_content(content, {:scene_notes, "scene-2"}) ==
             "Scene two"
  end

  defp write_commit(repo, path, content, message, timestamp) do
    File.write!(path, content)

    env = [
      {"GIT_AUTHOR_DATE", timestamp},
      {"GIT_COMMITTER_DATE", timestamp}
    ]

    System.cmd("git", ["add", "-A"], cd: repo, env: env)
    System.cmd("git", ["commit", "-m", message], cd: repo, env: env)
  end
end
