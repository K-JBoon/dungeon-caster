defmodule CampaignToolWeb.SessionChannel do
  use Phoenix.Channel
  alias CampaignTool.Session.Server

  @impl true
  def join("session:live:" <> session_id = topic, _params, socket) do
    case Registry.lookup(CampaignTool.Session.Registry, session_id) do
      [{_pid, _}] ->
        # Subscribe to PubSub so we can forward events to this socket
        Phoenix.PubSub.subscribe(CampaignTool.PubSub, topic)
        state = Server.get_state(session_id)
        initial = %{
          current_map: state.current_map,
          fog_grid: serialize_fog(state.fog_grid),
          audio_state: state.audio_state
        }
        {:ok, initial, assign(socket, :session_id, session_id)}

      [] ->
        {:error, %{reason: "session not active"}}
    end
  end

  # Forward PubSub messages to the connected receiver socket
  @impl true
  def handle_info({event, payload}, socket) when is_binary(event) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info({event, payload}, socket) when is_atom(event) do
    push(socket, Atom.to_string(event), Jason.encode!(payload) |> Jason.decode!())
    {:noreply, socket}
  end

  # Receivers send no upstream messages; ignore them
  @impl true
  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  defp serialize_fog(:all_revealed), do: "all_revealed"
  defp serialize_fog(grid) when is_map(grid), do: grid
end
