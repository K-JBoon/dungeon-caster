defmodule CampaignTool.Session.Server do
  @moduledoc "In-memory GenServer for a live D&D session. One process per active session."
  use GenServer

  @derive [Inspect]
  defstruct session_id: nil,
            current_map: nil,
            current_map_asset: nil,
            grid_cols: nil,
            grid_rows: nil,
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
  def set_map(sid, map_id, asset, grid_cols, grid_rows), do: GenServer.call(via(sid), {:set_map, map_id, asset, grid_cols, grid_rows})
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

  # fog_grid states: %{} = clear, %{cell => true} = blacklist, :all_fogged = full cover,
  # {:partial_reveal, map} = full cover except whitelisted cells.
  #
  # Incremental brush strokes broadcast only the delta cells (newly revealed/covered)
  # so the payload stays O(stroke size) rather than O(total revealed area).
  # Bulk operations (hide_all, reveal_all, set_map) still send the full state.

  def handle_call({:reveal_cells, cells}, _from, %{fog_grid: :all_fogged} = state) do
    new_revealed = Map.new(cells, &{&1, true})
    new_state = %{state | fog_grid: {:partial_reveal, new_revealed}}
    broadcast(state.session_id, "fog_update", {:delta_reveal, cells})
    {:reply, :ok, new_state}
  end

  def handle_call({:reveal_cells, cells}, _from, %{fog_grid: {:partial_reveal, revealed}} = state) do
    new_cells = Enum.reject(cells, &Map.has_key?(revealed, &1))
    new_revealed = Enum.reduce(new_cells, revealed, &Map.put(&2, &1, true))
    new_state = %{state | fog_grid: {:partial_reveal, new_revealed}}
    broadcast(state.session_id, "fog_update", {:delta_reveal, new_cells})
    {:reply, :ok, new_state}
  end

  def handle_call({:reveal_cells, cells}, _from, state) do
    {newly_revealed, new_fog} =
      Enum.reduce(cells, {[], state.fog_grid}, fn cell, {acc, grid} ->
        if Map.has_key?(grid, cell),
          do: {[cell | acc], Map.delete(grid, cell)},
          else: {acc, grid}
      end)
    new_state = %{state | fog_grid: new_fog}
    broadcast(state.session_id, "fog_update", {:delta_reveal, newly_revealed})
    {:reply, :ok, new_state}
  end

  def handle_call({:hide_cells, _cells}, _from, %{fog_grid: :all_fogged} = state) do
    {:reply, :ok, state}
  end

  def handle_call({:hide_cells, cells}, _from, %{fog_grid: {:partial_reveal, revealed}} = state) do
    {newly_covered, new_revealed} =
      Enum.reduce(cells, {[], revealed}, fn cell, {acc, grid} ->
        if Map.has_key?(grid, cell),
          do: {[cell | acc], Map.delete(grid, cell)},
          else: {acc, grid}
      end)
    new_state = %{state | fog_grid: {:partial_reveal, new_revealed}}
    broadcast(state.session_id, "fog_update", {:delta_cover, newly_covered})
    {:reply, :ok, new_state}
  end

  def handle_call({:hide_cells, cells}, _from, state) do
    {newly_covered, new_fog} =
      Enum.reduce(cells, {[], state.fog_grid}, fn cell, {acc, grid} ->
        if not Map.has_key?(grid, cell),
          do: {[cell | acc], Map.put(grid, cell, true)},
          else: {acc, grid}
      end)
    new_state = %{state | fog_grid: new_fog}
    broadcast(state.session_id, "fog_update", {:delta_cover, newly_covered})
    {:reply, :ok, new_state}
  end

  def handle_call({:set_map, map_id, asset, grid_cols, grid_rows}, _from, state) do
    new_state = %{state | current_map: map_id, current_map_asset: asset, grid_cols: grid_cols, grid_rows: grid_rows, fog_grid: :all_fogged, drawings: [], show_player_qr: false}
    broadcast(state.session_id, "map_update", %{map_id: map_id, asset: asset, grid_cols: grid_cols, grid_rows: grid_rows})
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
