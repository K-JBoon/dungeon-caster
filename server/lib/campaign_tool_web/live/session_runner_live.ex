defmodule CampaignToolWeb.SessionRunnerLive do
  use CampaignToolWeb, :live_view
  alias CampaignTool.{Entities, Session.Server, Audio}

  def mount(%{"id" => session_id}, _session, socket) do
    Phoenix.PubSub.subscribe(CampaignTool.PubSub, "session:live:#{session_id}")
    session = Entities.get_entity!("session", session_id)
    server_state = Server.get_state(session_id)
    music = Audio.list_music()
    sfx = Audio.list_sfx()

    {:ok, assign(socket,
      session_id: session_id,
      session: session,
      mode: :plan,
      scenes: parse_scenes(session),
      notes: "",
      server_state: server_state,
      music: music,
      sfx: sfx,
      expanded_entity: nil
    )}
  end

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: String.to_existing_atom(mode))}
  end

  def handle_event("save_notes", %{"notes" => notes}, socket) do
    session = socket.assigns.session
    content = File.read!(session.file_path)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    appended = content <> "\n\n### Session Notes (#{timestamp})\n\n#{notes}\n"
    File.write!(session.file_path, appended)
    {:noreply, assign(socket, notes: "")}
  end

  # Map mode events
  def handle_event("reveal_cells", %{"cells" => cells}, socket) do
    Server.reveal_cells(socket.assigns.session_id, cells)
    {:noreply, socket}
  end

  def handle_event("hide_all", _, socket) do
    Server.hide_all(socket.assigns.session_id)
    {:noreply, socket}
  end

  def handle_event("reveal_all", _, socket) do
    Server.reveal_all(socket.assigns.session_id)
    {:noreply, socket}
  end

  def handle_event("set_map", %{"map_id" => map_id}, socket) do
    Server.set_map(socket.assigns.session_id, map_id)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  # Audio events
  def handle_event("play_ambient", %{"path" => path}, socket) do
    Server.play_audio(socket.assigns.session_id, path, :ambient)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  def handle_event("stop_ambient", _, socket) do
    Server.stop_audio(socket.assigns.session_id, :ambient)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  def handle_event("play_sfx", %{"path" => path}, socket) do
    Server.play_audio(socket.assigns.session_id, path, :sfx)
    {:noreply, socket}
  end

  def handle_event("set_volume", %{"master" => m, "ambient" => a, "sfx" => s}, socket) do
    vol = %{
      master: String.to_integer(m),
      ambient: String.to_integer(a),
      sfx: String.to_integer(s)
    }
    Server.set_volume(socket.assigns.session_id, vol)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  # Combat events
  def handle_event("add_combatant", %{"name" => name, "hp" => hp, "ac" => ac}, socket) do
    combatant = %{
      id: "c-#{:rand.uniform(99999)}",
      name: name,
      hp: String.to_integer(hp),
      max_hp: String.to_integer(hp),
      ac: String.to_integer(ac),
      conditions: []
    }
    state = socket.assigns.server_state
    new_initiative = state.initiative ++ [combatant]
    Server.set_initiative(socket.assigns.session_id, new_initiative)
    {:noreply, assign(socket, server_state: %{state | initiative: new_initiative})}
  end

  def handle_event("update_hp", %{"id" => id, "hp" => hp}, socket) do
    Server.update_hp(socket.assigns.session_id, id, String.to_integer(hp))
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  # PubSub
  def handle_info({"fog_update", %{fog_grid: fog_grid}}, socket) do
    {:noreply, push_event(socket, "fog_state", %{fog_grid: fog_grid})}
  end
  def handle_info(_, socket), do: {:noreply, socket}

  defp parse_scenes(session) do
    case session.scenes do
      nil -> []
      json when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, list} when is_list(list) -> list
          _ -> []
        end
      list when is_list(list) -> list
    end
  end

  def render(assigns) do
    ~H"""
    <div style="display:flex; flex-direction:column; height:100vh; font-family:sans-serif">
      <!-- Content area -->
      <div style="flex:1; overflow-y:auto; padding:1rem">
        <%= case @mode do %>
          <% :plan -> %> <%= render_plan(assigns) %>
          <% :map -> %> <%= render_map(assigns) %>
          <% :combat -> %> <%= render_combat(assigns) %>
          <% :audio -> %> <%= render_audio(assigns) %>
        <% end %>
      </div>

      <!-- Bottom nav -->
      <nav style="display:flex; border-top:2px solid #333; background:#1a1a2e">
        <%= for {mode, label, icon} <- [{:plan, "Plan", "📋"}, {:map, "Map", "🗺"}, {:combat, "Combat", "⚔"}, {:audio, "Audio", "🎵"}] do %>
          <button
            phx-click="set_mode" phx-value-mode={mode}
            style={"flex:1; padding:12px; background:#{if @mode == mode, do: "#16213e", else: "transparent"}; color:white; border:none; font-size:0.9rem; cursor:pointer"}>
            <%= icon %> <%= label %>
          </button>
        <% end %>
      </nav>
    </div>
    """
  end

  defp render_plan(assigns) do
    ~H"""
    <div>
      <h2 style="margin-bottom:1rem"><%= @session.title %></h2>
      <%= for scene <- @scenes do %>
        <div style="margin-bottom:2rem; border-bottom:1px solid #eee; padding-bottom:1rem">
          <h3><%= scene["title"] %></h3>
          <div><%= Phoenix.HTML.raw(Earmark.as_html!(scene["notes"] || "")) %></div>
        </div>
      <% end %>
      <div style="margin-top:2rem">
        <h4>Session Notes</h4>
        <form phx-submit="save_notes">
          <textarea name="notes" rows="6" style="width:100%" placeholder="Notes..."><%= @notes %></textarea>
          <button type="submit">Save Notes</button>
        </form>
      </div>
    </div>
    """
  end

  defp render_map(assigns) do
    ~H"""
    <div>
      <div style="display:flex; gap:0.5rem; margin-bottom:1rem; align-items:center">
        <button phx-click="reveal_all">Reveal All</button>
        <button phx-click="hide_all">Hide All</button>
        <label>Brush:
          <input type="range" min="1" max="10" value="3" id="brush-radius" />
        </label>
      </div>
      <div style="position:relative; display:inline-block">
        <%= if @server_state.current_map do %>
          <img id="map-thumb" src={"/maps/assets/#{@server_state.current_map}.png"} style="max-width:100%" />
          <canvas id="fog-editor"
            data-session-id={@session_id}
            data-cell-size="20"
            phx-hook="FogEditor"
            style="position:absolute; top:0; left:0; width:100%; height:100%; cursor:crosshair">
          </canvas>
        <% else %>
          <p>No map selected. Select a map from session assets.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_combat(assigns) do
    ~H"""
    <div>
      <h3>Initiative Tracker</h3>
      <form phx-submit="add_combatant" style="display:flex; gap:0.5rem; margin-bottom:1rem">
        <input name="name" placeholder="Name" required />
        <input name="hp" placeholder="HP" type="number" required style="width:70px" />
        <input name="ac" placeholder="AC" type="number" required style="width:70px" />
        <button type="submit">+ Add</button>
      </form>
      <table style="width:100%; border-collapse:collapse">
        <tr><th>Name</th><th>HP</th><th>AC</th><th>Conditions</th></tr>
        <%= for c <- @server_state.initiative do %>
          <tr style="border-bottom:1px solid #eee">
            <td><%= c.name %></td>
            <td>
              <input type="number" value={c.hp}
                phx-blur="update_hp" phx-value-id={c.id}
                name="hp" style="width:60px" />
              / <%= c.max_hp %>
            </td>
            <td><%= c.ac %></td>
            <td>—</td>
          </tr>
        <% end %>
      </table>
    </div>
    """
  end

  defp render_audio(assigns) do
    ~H"""
    <div>
      <!-- Volume -->
      <div style="margin-bottom:1.5rem">
        <h4>Volume</h4>
        <form phx-change="set_volume">
          <label>Master <input type="range" name="master" min="0" max="100"
            value={@server_state.audio_state.volume.master} /></label><br/>
          <label>Ambient <input type="range" name="ambient" min="0" max="100"
            value={@server_state.audio_state.volume.ambient} /></label><br/>
          <label>SFX <input type="range" name="sfx" min="0" max="100"
            value={@server_state.audio_state.volume.sfx} /></label>
        </form>
      </div>

      <!-- Ambient -->
      <div style="margin-bottom:1.5rem">
        <h4>Ambient Music</h4>
        <%= if @server_state.audio_state.ambient do %>
          <p>▶ Playing: <%= @server_state.audio_state.ambient %></p>
          <button phx-click="stop_ambient">Stop</button>
        <% end %>
        <ul>
          <%= for track <- @music do %>
            <li>
              <button phx-click="play_ambient" phx-value-path={track.path}><%= track.name %></button>
            </li>
          <% end %>
        </ul>
      </div>

      <!-- Soundboard -->
      <div>
        <h4>SFX Soundboard</h4>
        <%= for {section, sfx_list} <- Enum.group_by(@sfx, & &1.section) do %>
          <h5><%= section %></h5>
          <div style="display:flex; flex-wrap:wrap; gap:0.5rem; margin-bottom:1rem">
            <%= for sfx <- sfx_list do %>
              <button phx-click="play_sfx" phx-value-path={sfx.path}
                style="padding:8px 12px; background:#2d4a7a; color:white; border:none; border-radius:4px; cursor:pointer">
                <%= sfx.name %>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
