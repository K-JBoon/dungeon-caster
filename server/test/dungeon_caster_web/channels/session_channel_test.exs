defmodule DungeonCasterWeb.SessionChannelTest do
  use DungeonCasterWeb.ChannelCase
  alias DungeonCaster.Session.Server

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
      DungeonCasterWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(DungeonCasterWeb.SessionChannel, "session:live:#{sid}")

    assert reply.current_map == nil
    assert reply.fog_grid == %{}
  end

  test "cannot join channel for non-active session" do
    result =
      DungeonCasterWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(DungeonCasterWeb.SessionChannel, "session:live:nonexistent-99999")

    assert {:error, %{reason: "session not active"}} = result
  end

  test "join includes drawings and show_player_qr in initial state", %{sid: sid} do
    {:ok, reply, _socket} =
      DungeonCasterWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(DungeonCasterWeb.SessionChannel, "session:live:#{sid}")

    assert reply.drawings == []
    assert reply.show_player_qr == false
  end

  test "drawing_stroke event is stored and broadcast", %{sid: sid} do
    {:ok, _reply, socket} =
      DungeonCasterWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(DungeonCasterWeb.SessionChannel, "session:live:#{sid}")

    stroke = %{
      "player_id" => "p1",
      "color" => "#ff0000",
      "size" => 6,
      "erase" => false,
      "points" => []
    }

    push(socket, "drawing_stroke", stroke)
    # give GenServer time to process
    Process.sleep(50)

    state = DungeonCaster.Session.Server.get_state(sid)
    assert length(state.drawings) == 1
  end

  test "clear_my_drawings event removes player strokes", %{sid: sid} do
    s = %{player_id: "p1", color: "#f00", size: 4, erase: false, points: []}
    DungeonCaster.Session.Server.add_stroke(sid, s)

    {:ok, _reply, socket} =
      DungeonCasterWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(DungeonCasterWeb.SessionChannel, "session:live:#{sid}")

    push(socket, "clear_my_drawings", %{"player_id" => "p1"})
    Process.sleep(50)

    state = DungeonCaster.Session.Server.get_state(sid)
    assert state.drawings == []
  end
end
