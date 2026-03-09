defmodule CampaignTool.Session.Server do
  @moduledoc "In-memory GenServer for a live D&D session. One process per active session."
  use GenServer

  @derive [Inspect]
  defstruct session_id: nil,
            current_map: nil,
            fog_grid: %{},
            audio_state: %{
              ambient: nil,
              volume: %{master: 80, ambient: 80, sfx: 80}
            },
            initiative: [],
            drawings: [],
            show_player_qr: false

  # -- Public API --

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via(session_id))
  end

  def stop(session_id) do
    GenServer.stop(via(session_id))
  end

  def via(session_id) do
    {:via, Registry, {CampaignTool.Session.Registry, session_id}}
  end

  def get_state(sid), do: GenServer.call(via(sid), :get_state)
  def reveal_cells(sid, cells), do: GenServer.call(via(sid), {:reveal_cells, cells})
  def hide_cells(sid, cells), do: GenServer.call(via(sid), {:hide_cells, cells})
  def set_map(sid, map_id), do: GenServer.call(via(sid), {:set_map, map_id})
  def reveal_all(sid), do: GenServer.call(via(sid), :reveal_all)
  def hide_all(sid), do: GenServer.call(via(sid), :hide_all)
  def play_audio(sid, path, type), do: GenServer.call(via(sid), {:play_audio, path, type})
  def stop_audio(sid, type), do: GenServer.call(via(sid), {:stop_audio, type})
  def set_volume(sid, vol), do: GenServer.call(via(sid), {:set_volume, vol})
  def set_initiative(sid, list), do: GenServer.call(via(sid), {:set_initiative, list})
  def update_hp(sid, combatant_id, hp), do: GenServer.call(via(sid), {:update_hp, combatant_id, hp})
  def add_stroke(sid, stroke), do: GenServer.call(via(sid), {:add_stroke, stroke})
  def clear_player_drawings(sid, player_id), do: GenServer.call(via(sid), {:clear_player_drawings, player_id})
  def clear_all_drawings(sid), do: GenServer.call(via(sid), :clear_all_drawings)
  def toggle_player_qr(sid), do: GenServer.call(via(sid), :toggle_player_qr)

  # -- GenServer callbacks --

  def init(session_id) do
    {:ok, %__MODULE__{session_id: session_id}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # fog_grid states: %{} = clear, %{cell => true} = blacklist, :all_fogged = full cover,
  # {:partial_reveal, map} = full cover except whitelisted cells.

  # :all_fogged → reveal cells → transition to {:partial_reveal, revealed_map}
  # {:partial_reveal, map} means "entire map fogged except these cells"
  def handle_call({:reveal_cells, cells}, _from, %{fog_grid: :all_fogged} = state) do
    revealed = Enum.reduce(cells, %{}, fn cell, acc -> Map.put(acc, cell, true) end)
    new_fog = {:partial_reveal, revealed}
    new_state = %{state | fog_grid: new_fog}
    broadcast(state.session_id, "fog_update", new_fog)
    {:reply, :ok, new_state}
  end

  def handle_call({:reveal_cells, cells}, _from, %{fog_grid: {:partial_reveal, revealed}} = state) do
    new_revealed = Enum.reduce(cells, revealed, fn cell, acc -> Map.put(acc, cell, true) end)
    new_fog = {:partial_reveal, new_revealed}
    new_state = %{state | fog_grid: new_fog}
    broadcast(state.session_id, "fog_update", new_fog)
    {:reply, :ok, new_state}
  end

  def handle_call({:reveal_cells, cells}, _from, state) do
    fog = Enum.reduce(cells, state.fog_grid, fn cell, acc -> Map.delete(acc, cell) end)
    new_state = %{state | fog_grid: fog}
    broadcast(state.session_id, "fog_update", fog)
    {:reply, :ok, new_state}
  end

  def handle_call({:hide_cells, _cells}, _from, %{fog_grid: :all_fogged} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:hide_cells, cells}, _from, %{fog_grid: {:partial_reveal, revealed}} = state) do
    new_revealed = Enum.reduce(cells, revealed, fn cell, acc -> Map.delete(acc, cell) end)
    new_fog = {:partial_reveal, new_revealed}
    new_state = %{state | fog_grid: new_fog}
    broadcast(state.session_id, "fog_update", new_fog)
    {:reply, :ok, new_state}
  end

  def handle_call({:hide_cells, cells}, _from, state) do
    fog = Enum.reduce(cells, state.fog_grid, fn cell, acc -> Map.put(acc, cell, true) end)
    new_state = %{state | fog_grid: fog}
    broadcast(state.session_id, "fog_update", fog)
    {:reply, :ok, new_state}
  end

  def handle_call({:set_map, map_id}, _from, state) do
    new_state = %{state | current_map: map_id, fog_grid: :all_fogged, drawings: [], show_player_qr: false}
    broadcast(state.session_id, "map_update", %{map_id: map_id})
    broadcast(state.session_id, "fog_update", :all_fogged)
    broadcast(state.session_id, "drawing_update", %{strokes: []})
    broadcast(state.session_id, "qr_toggle", %{visible: false})
    {:reply, :ok, new_state}
  end

  def handle_call(:reveal_all, _from, state) do
    new_state = %{state | fog_grid: %{}}
    broadcast(state.session_id, "fog_update", %{})
    {:reply, :ok, new_state}
  end

  def handle_call(:hide_all, _from, state) do
    new_state = %{state | fog_grid: :all_fogged}
    broadcast(state.session_id, "fog_update", :all_fogged)
    {:reply, :ok, new_state}
  end

  def handle_call({:play_audio, path, :ambient}, _from, state) do
    audio = %{state.audio_state | ambient: path}
    new_state = %{state | audio_state: audio}
    broadcast(state.session_id, "audio_play", %{
      path: path,
      type: "ambient",
      volume: state.audio_state.volume
    })
    {:reply, :ok, new_state}
  end

  def handle_call({:play_audio, path, :sfx}, _from, state) do
    broadcast(state.session_id, "audio_play", %{
      path: path,
      type: "sfx",
      volume: state.audio_state.volume
    })
    {:reply, :ok, state}
  end

  def handle_call({:stop_audio, :ambient}, _from, state) do
    audio = %{state.audio_state | ambient: nil}
    new_state = %{state | audio_state: audio}
    broadcast(state.session_id, "audio_stop", %{type: "ambient"})
    {:reply, :ok, new_state}
  end

  def handle_call({:set_volume, vol}, _from, state) do
    current = state.audio_state.volume
    new_vol = %{master: Map.get(vol, :master, current.master),
                ambient: Map.get(vol, :ambient, current.ambient),
                sfx: Map.get(vol, :sfx, current.sfx)}
    audio = %{state.audio_state | volume: new_vol}
    new_state = %{state | audio_state: audio}
    broadcast(state.session_id, "volume_update", %{volume: new_vol})
    {:reply, :ok, new_state}
  end

  def handle_call({:set_initiative, list}, _from, state) do
    broadcast(state.session_id, "initiative_update", %{initiative: list})
    {:reply, :ok, %{state | initiative: list}}
  end

  def handle_call({:update_hp, combatant_id, hp}, _from, state) do
    initiative = Enum.map(state.initiative, fn c ->
      if c.id == combatant_id, do: %{c | hp: hp}, else: c
    end)
    broadcast(state.session_id, "initiative_update", %{initiative: initiative})
    {:reply, :ok, %{state | initiative: initiative}}
  end

  def handle_call({:add_stroke, stroke}, _from, state) do
    new_drawings = [stroke | state.drawings]
    new_state = %{state | drawings: new_drawings}
    broadcast(state.session_id, "drawing_stroke", stroke)
    {:reply, :ok, new_state}
  end

  def handle_call({:clear_player_drawings, player_id}, _from, state) do
    new_drawings = Enum.filter(state.drawings, fn s -> s.player_id != player_id end)
    new_state = %{state | drawings: new_drawings}
    broadcast(state.session_id, "drawing_update", %{strokes: Enum.reverse(new_drawings)})
    {:reply, :ok, new_state}
  end

  def handle_call(:clear_all_drawings, _from, state) do
    new_state = %{state | drawings: []}
    broadcast(state.session_id, "drawing_update", %{strokes: []})
    {:reply, :ok, new_state}
  end

  def handle_call(:toggle_player_qr, _from, state) do
    new_visible = !state.show_player_qr
    new_state = %{state | show_player_qr: new_visible}
    broadcast(state.session_id, "qr_toggle", %{visible: new_visible})
    {:reply, :ok, new_state}
  end

  # -- Private --

  defp broadcast(session_id, event, payload) do
    Phoenix.PubSub.broadcast(
      CampaignTool.PubSub,
      "session:live:#{session_id}",
      {event, payload}
    )
  end
end
