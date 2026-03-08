defmodule CampaignTool.Sync.GitWorkerTest do
  use ExUnit.Case

  setup do
    # Create a temp git repo to test against
    tmp = System.tmp_dir!() |> Path.join("campaign_git_test_#{:rand.uniform(999_999)}")
    File.mkdir_p!(tmp)
    System.cmd("git", ["init"], cd: tmp)
    System.cmd("git", ["config", "user.email", "test@test.com"], cd: tmp)
    System.cmd("git", ["config", "user.name", "Test"], cd: tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  test "git_commit/1 stages and commits all changes", %{tmp: tmp} do
    File.write!(Path.join(tmp, "test.md"), "hello world")
    assert :ok = CampaignTool.Sync.GitWorker.git_commit(tmp)
    {log, 0} = System.cmd("git", ["log", "--oneline"], cd: tmp)
    assert log =~ "Campaign Tool auto-save"
  end

  test "git_commit/1 returns :ok even with nothing to commit", %{tmp: tmp} do
    # Empty repo — git commit will fail but we handle it gracefully
    assert :ok = CampaignTool.Sync.GitWorker.git_commit(tmp)
  end
end
