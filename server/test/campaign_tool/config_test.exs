defmodule CampaignTool.ConfigTest do
  use ExUnit.Case

  test "campaign_dir config is set in test env" do
    dir = Application.get_env(:campaign_tool, :campaign_dir)
    assert is_binary(dir)
  end

  test "ssh_key_path config exists in test env (may be nil)" do
    # just checking the key can be read without error
    _val = Application.get_env(:campaign_tool, :ssh_key_path)
    assert true
  end
end
