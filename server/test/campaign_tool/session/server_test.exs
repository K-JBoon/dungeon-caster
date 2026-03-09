defmodule CampaignTool.Session.ServerTest do
  use ExUnit.Case

  setup do
    sid = "test-session-#{:rand.uniform(999_999)}"
    {:ok, _pid} = CampaignTool.Session.Server.start_link(sid)
    on_exit(fn ->
      try do
        CampaignTool.Session.Server.stop(sid)
      catch
        :exit, _ -> :ok
      end
    end)
    {:ok, sid: sid}
  end

  test "starts with empty fog grid", %{sid: sid} do
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.fog_grid == %{}
    assert state.current_map == nil
    assert state.initiative == []
  end

  test "reveal_cells adds cells to fog grid", %{sid: sid} do
    :ok = CampaignTool.Session.Server.reveal_cells(sid, ["0,0", "0,1", "1,0"])
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.fog_grid["0,0"] == true
    assert state.fog_grid["0,1"] == true
    assert state.fog_grid["1,0"] == true
    refute Map.has_key?(state.fog_grid, "5,5")
  end

  test "hide_cells removes revealed cells", %{sid: sid} do
    CampaignTool.Session.Server.reveal_cells(sid, ["0,0", "0,1"])
    :ok = CampaignTool.Session.Server.hide_cells(sid, ["0,0"])
    state = CampaignTool.Session.Server.get_state(sid)
    refute Map.has_key?(state.fog_grid, "0,0")
    assert state.fog_grid["0,1"] == true
  end

  test "set_map updates current_map and resets fog", %{sid: sid} do
    CampaignTool.Session.Server.reveal_cells(sid, ["0,0"])
    :ok = CampaignTool.Session.Server.set_map(sid, "dungeon-level-1")
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.current_map == "dungeon-level-1"
    assert state.fog_grid == %{}
  end

  test "reveal_all sets fog_grid to :all_revealed", %{sid: sid} do
    :ok = CampaignTool.Session.Server.reveal_all(sid)
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.fog_grid == :all_revealed
  end

  test "hide_all resets fog_grid to empty map", %{sid: sid} do
    CampaignTool.Session.Server.reveal_all(sid)
    :ok = CampaignTool.Session.Server.hide_all(sid)
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.fog_grid == %{}
  end

  test "play_audio :ambient sets ambient track", %{sid: sid} do
    :ok = CampaignTool.Session.Server.play_audio(sid, "music/tavern.mp3", :ambient)
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.audio_state.ambient == "music/tavern.mp3"
  end

  test "stop_audio :ambient clears ambient track", %{sid: sid} do
    CampaignTool.Session.Server.play_audio(sid, "music/tavern.mp3", :ambient)
    :ok = CampaignTool.Session.Server.stop_audio(sid, :ambient)
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.audio_state.ambient == nil
  end

  test "set_volume updates volume map", %{sid: sid} do
    :ok = CampaignTool.Session.Server.set_volume(sid, %{master: 60, ambient: 70, sfx: 100})
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.audio_state.volume.master == 60
    assert state.audio_state.volume.ambient == 70
  end

  test "set_initiative stores combatants", %{sid: sid} do
    combatants = [
      %{id: "c1", name: "Goblin", hp: 7, max_hp: 7, ac: 13, conditions: []},
      %{id: "c2", name: "Fighter", hp: 20, max_hp: 20, ac: 16, conditions: []}
    ]
    :ok = CampaignTool.Session.Server.set_initiative(sid, combatants)
    state = CampaignTool.Session.Server.get_state(sid)
    assert length(state.initiative) == 2
    assert Enum.at(state.initiative, 0).name == "Goblin"
  end

  test "update_hp changes hp of specific combatant", %{sid: sid} do
    combatants = [%{id: "c1", name: "Goblin", hp: 7, max_hp: 7, ac: 13, conditions: []}]
    CampaignTool.Session.Server.set_initiative(sid, combatants)
    :ok = CampaignTool.Session.Server.update_hp(sid, "c1", 3)
    state = CampaignTool.Session.Server.get_state(sid)
    assert Enum.at(state.initiative, 0).hp == 3
  end

  test "reveal_cells on :all_revealed state is a no-op and does not crash", %{sid: sid} do
    :ok = CampaignTool.Session.Server.reveal_all(sid)
    assert :ok = CampaignTool.Session.Server.reveal_cells(sid, ["0,0", "1,1"])
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.fog_grid == :all_revealed
  end

  test "set_volume with 0 for master sets master to 0", %{sid: sid} do
    :ok = CampaignTool.Session.Server.set_volume(sid, %{master: 0})
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.audio_state.volume.master == 0
  end

  test "starts with empty drawings and show_player_qr false", %{sid: sid} do
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.drawings == []
    assert state.show_player_qr == false
  end

  test "add_stroke prepends stroke to drawings", %{sid: sid} do
    stroke1 = %{player_id: "p1", color: "#ff0000", size: 4, points: [{0, 0}, {10, 10}]}
    stroke2 = %{player_id: "p1", color: "#0000ff", size: 2, points: [{5, 5}, {15, 15}]}
    :ok = CampaignTool.Session.Server.add_stroke(sid, stroke1)
    :ok = CampaignTool.Session.Server.add_stroke(sid, stroke2)
    state = CampaignTool.Session.Server.get_state(sid)
    # newest-first in state
    assert hd(state.drawings) == stroke2
    assert length(state.drawings) == 2
  end

  test "clear_player_drawings removes only that player's strokes", %{sid: sid} do
    stroke_p1 = %{player_id: "p1", color: "#ff0000", size: 4, points: []}
    stroke_p2 = %{player_id: "p2", color: "#00ff00", size: 4, points: []}
    CampaignTool.Session.Server.add_stroke(sid, stroke_p1)
    CampaignTool.Session.Server.add_stroke(sid, stroke_p2)
    :ok = CampaignTool.Session.Server.clear_player_drawings(sid, "p1")
    state = CampaignTool.Session.Server.get_state(sid)
    assert length(state.drawings) == 1
    assert hd(state.drawings).player_id == "p2"
  end

  test "clear_all_drawings empties the drawings list", %{sid: sid} do
    CampaignTool.Session.Server.add_stroke(sid, %{player_id: "p1", color: "#fff", size: 2, points: []})
    :ok = CampaignTool.Session.Server.clear_all_drawings(sid)
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.drawings == []
  end

  test "set_map resets drawings and show_player_qr", %{sid: sid} do
    CampaignTool.Session.Server.add_stroke(sid, %{player_id: "p1", color: "#fff", size: 2, points: []})
    CampaignTool.Session.Server.toggle_player_qr(sid)
    :ok = CampaignTool.Session.Server.set_map(sid, "new-map")
    state = CampaignTool.Session.Server.get_state(sid)
    assert state.drawings == []
    assert state.show_player_qr == false
  end

  test "toggle_player_qr flips show_player_qr", %{sid: sid} do
    assert CampaignTool.Session.Server.get_state(sid).show_player_qr == false
    :ok = CampaignTool.Session.Server.toggle_player_qr(sid)
    assert CampaignTool.Session.Server.get_state(sid).show_player_qr == true
    :ok = CampaignTool.Session.Server.toggle_player_qr(sid)
    assert CampaignTool.Session.Server.get_state(sid).show_player_qr == false
  end
end
