defmodule CampaignToolWeb.SessionChannelTest do
  use CampaignToolWeb.ChannelCase
  alias CampaignTool.Session.Server

  setup do
    sid = "channel-test-#{:rand.uniform(99_999)}"
    {:ok, _} = Server.start_link(sid)
    on_exit(fn ->
      try do
        Server.stop(sid)
      catch
        :exit, _ -> :ok
      end
    end)
    {:ok, sid: sid}
  end

  test "joins channel and receives initial state", %{sid: sid} do
    {:ok, reply, _socket} =
      CampaignToolWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(CampaignToolWeb.SessionChannel, "session:live:#{sid}")

    assert reply.current_map == nil
    assert reply.fog_grid == %{}
  end

  test "cannot join channel for non-active session" do
    result =
      CampaignToolWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(CampaignToolWeb.SessionChannel, "session:live:nonexistent-99999")

    assert {:error, %{reason: "session not active"}} = result
  end
end
