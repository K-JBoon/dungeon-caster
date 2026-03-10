defmodule DungeonCasterWeb.SessionChannel do
  use Phoenix.Channel
  alias DungeonCaster.Session.Server

  @impl true
  def join("session:live:" <> session_id = topic, _params, socket) do
    case Registry.lookup(DungeonCaster.Session.Registry, session_id) do
      [{_pid, _}] ->
        # Subscribe to PubSub so we can forward events to this socket
        Phoenix.PubSub.subscribe(DungeonCaster.PubSub, topic)
        state = Server.get_state(session_id)
        initial = %{
          current_map: state.current_map,
          current_map_asset: state.current_map_asset,
          grid_cols: state.grid_cols,
          grid_rows: state.grid_rows,
          fog_grid: serialize_fog(state.fog_grid),
          audio_state: state.audio_state,
          drawings: Enum.reverse(state.drawings),
          show_player_qr: state.show_player_qr
        }
        {:ok, initial, assign(socket, :session_id, session_id)}

      [] ->
        {:error, %{reason: "session not active"}}
    end
  end

  # Forward PubSub messages to the connected receiver socket

  # fog_update payload can be an atom or tuple — serialize it before pushing
  @impl true
  def handle_info({"fog_update", fog}, socket) do
    push(socket, "fog_update", %{fog_grid: serialize_fog(fog)})
    {:noreply, socket}
  end

  def handle_info({event, payload}, socket) when is_binary(event) and is_map(payload) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info({event, payload}, socket) when is_atom(event) and is_map(payload) do
    push(socket, Atom.to_string(event), Jason.encode!(payload) |> Jason.decode!())
    {:noreply, socket}
  end

  @impl true
  def handle_in("drawing_stroke", stroke, socket) do
    Server.add_stroke(socket.assigns.session_id, atomize_stroke(stroke))
    {:noreply, socket}
  end

  @impl true
  def handle_in("clear_my_drawings", %{"player_id" => player_id}, socket) do
    Server.clear_player_drawings(socket.assigns.session_id, player_id)
    {:noreply, socket}
  end

  @impl true
  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  defp atomize_stroke(s) do
    %{
      player_id: s["player_id"],
      color: s["color"],
      size: s["size"],
      erase: s["erase"] || false,
      points: Enum.map(s["points"] || [], fn p -> %{x: p["x"], y: p["y"]} end)
    }
  end

  defp serialize_fog(:all_fogged), do: "all_fogged"
  defp serialize_fog(:all_revealed), do: "all_revealed"
  defp serialize_fog({:partial_reveal, revealed}), do: %{type: "partial_reveal", revealed: revealed}
  defp serialize_fog({:delta_reveal, cells}), do: %{type: "delta_reveal", cells: cells}
  defp serialize_fog({:delta_cover, cells}), do: %{type: "delta_cover", cells: cells}
  defp serialize_fog(grid) when is_map(grid), do: grid
end
