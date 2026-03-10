defmodule DungeonCasterWeb.SessionRunnerLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.{Entities, Session.Server, Audio}
  alias DungeonCaster.Markdown
  alias DungeonCasterWeb.EntityHelpers

  def mount(%{"id" => session_id}, _session, socket) do
    Phoenix.PubSub.subscribe(DungeonCaster.PubSub, "session:live:#{session_id}")
    session = Entities.get_entity!("session", session_id)
    case Registry.lookup(DungeonCaster.Session.Registry, session_id) do
      [] -> Server.start_link(session_id)
      _ -> :ok
    end
    server_state = Server.get_state(session_id)
    music = Audio.list_music()
    sfx = Audio.list_sfx()
    scenes = parse_scenes(session)
    session_maps = collect_maps(session, scenes)

    {:ok,
     assign(socket,
       session_id: session_id,
       session: session,
       mode: :plan,
       scenes: scenes,
       scene_index: 0,
       notes: "",
       notes_open: false,
       expanded_entities: MapSet.new(),
       server_state: server_state,
       fog_mode: :eraser,
       session_maps: session_maps,
       music: music,
       sfx: sfx
     )}
  end

  # ── Mode / navigation ───────────────────────────────────────────────────────

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: String.to_existing_atom(mode))}
  end

  def handle_event("prev_scene", _, socket) do
    {:noreply, assign(socket,
      scene_index: max(0, socket.assigns.scene_index - 1),
      expanded_entities: MapSet.new())}
  end

  def handle_event("next_scene", _, socket) do
    max_idx = max(0, length(socket.assigns.scenes) - 1)
    {:noreply, assign(socket,
      scene_index: min(max_idx, socket.assigns.scene_index + 1),
      expanded_entities: MapSet.new())}
  end

  def handle_event("toggle_entity", %{"ref" => ref}, socket) do
    expanded = socket.assigns.expanded_entities
    new_expanded =
      if MapSet.member?(expanded, ref),
        do: MapSet.delete(expanded, ref),
        else: MapSet.put(expanded, ref)
    {:noreply, assign(socket, expanded_entities: new_expanded)}
  end

  # ── Notes ──────────────────────────────────────────────────────────────────

  def handle_event("open_notes", _, socket) do
    {:noreply, assign(socket, notes_open: true)}
  end

  def handle_event("close_notes", _, socket) do
    {:noreply, assign(socket, notes_open: false, notes: "")}
  end

  def handle_event("save_notes", %{"notes" => notes}, socket) do
    session = socket.assigns.session
    content = File.read!(session.file_path)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    appended = content <> "\n\n### Session Notes (#{timestamp})\n\n#{notes}\n"
    File.write!(session.file_path, appended)
    {:noreply, assign(socket, notes_open: false, notes: "")}
  end

  # ── Map mode ───────────────────────────────────────────────────────────────

  def handle_event("reveal_cells", %{"cells" => cells}, socket) do
    Server.reveal_cells(socket.assigns.session_id, cells)
    {:noreply, socket}
  end

  def handle_event("cover_cells", %{"cells" => cells}, socket) do
    Server.hide_cells(socket.assigns.session_id, cells)
    {:noreply, socket}
  end

  def handle_event("set_fog_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, fog_mode: String.to_existing_atom(mode))}
  end

  def handle_event("reveal_all", _, socket) do
    Server.reveal_all(socket.assigns.session_id)
    {:noreply, socket}
  end

  def handle_event("hide_all", _, socket) do
    Server.hide_all(socket.assigns.session_id)
    {:noreply, socket}
  end

  def handle_event("set_map", %{"map_id" => map_id}, socket) do
    map_entity = Enum.find(socket.assigns.session_maps, &(&1.id == map_id))
    asset = if map_entity && map_entity.asset_path != "",
      do: Path.basename(map_entity.asset_path),
      else: map_id <> ".png"
    {grid_cols, grid_rows} = image_grid_dims(map_entity && map_entity.asset_path)
    Server.set_map(socket.assigns.session_id, map_id, asset, grid_cols, grid_rows)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  def handle_event("toggle_player_qr", _, socket) do
    Server.toggle_player_qr(socket.assigns.session_id)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  def handle_event("clear_all_drawings", _, socket) do
    Server.clear_all_drawings(socket.assigns.session_id)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end

  # Read width/height from PNG file header (bytes 16-23) and compute grid dimensions.
  # Falls back to a sensible default for non-PNG or missing files.
  defp image_grid_dims(nil), do: {96, 54}
  defp image_grid_dims(""), do: {96, 54}
  defp image_grid_dims(asset_path) do
    campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir) |> Path.expand()
    path = Path.join([campaign_dir, "maps", asset_path])
    try do
      {:ok, fd} = :file.open(String.to_charlist(path), [:read, :binary])
      {:ok, _} = :file.position(fd, 16)
      {:ok, <<w::32-big, h::32-big>>} = :file.read(fd, 8)
      :file.close(fd)
      {ceil(w / 20), ceil(h / 20)}
    rescue
      _ -> {96, 54}
    end
  end

  # ── Audio events ───────────────────────────────────────────────────────────

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

  def handle_event("open_entity_popover", %{"ref" => ref}, socket) do
    case EntityHelpers.entity_popover_data(ref) do
      {:ok, data} ->
        {:noreply, push_event(socket, "entity:popover-open", data)}
      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("search_entities", %{"q" => q}, socket) do
    results = EntityHelpers.search_entities(q)
    {:reply, %{results: results}, socket}
  end

  # ── PubSub ─────────────────────────────────────────────────────────────────

  def handle_info({"fog_update", :all_fogged}, socket) do
    {:noreply, push_event(socket, "fog_state", %{fog_grid: "all_fogged"})}
  end
  def handle_info({"fog_update", {:partial_reveal, revealed}}, socket) do
    {:noreply, push_event(socket, "fog_state", %{fog_grid: %{mode: "partial_reveal", revealed: revealed}})}
  end
  # Delta updates from brush strokes — fog editor already updated its local state,
  # so no push_event needed here.
  def handle_info({"fog_update", {:delta_reveal, _}}, socket), do: {:noreply, socket}
  def handle_info({"fog_update", {:delta_cover, _}}, socket), do: {:noreply, socket}
  def handle_info({"fog_update", fog_grid}, socket) do
    {:noreply, push_event(socket, "fog_state", %{fog_grid: fog_grid})}
  end
  def handle_info({"qr_toggle", _}, socket) do
    # Refresh server_state so the QR toolbar button active state stays in sync
    # when the toggle is triggered by an external source (e.g. map change)
    state = Server.get_state(socket.assigns.session_id)
    {:noreply, assign(socket, server_state: state)}
  end
  def handle_info(_, socket), do: {:noreply, socket}

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp collect_maps(session, scenes) do
    from_session = (session.map_ids || [])
                   |> Enum.map(&Entities.get_entity("map", &1))
                   |> Enum.reject(&is_nil/1)

    from_scenes =
      scenes
      |> Enum.flat_map(fn s -> s["entity_ids"] || [] end)
      |> Enum.filter(&String.starts_with?(&1, "map:"))
      |> Enum.map(fn "map:" <> id -> Entities.get_entity("map", id) end)
      |> Enum.reject(&is_nil/1)

    (from_session ++ from_scenes)
    |> Enum.uniq_by(& &1.id)
  end

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

  defp entity_display_name(%{name: n}) when is_binary(n), do: n
  defp entity_display_name(%{title: t}) when is_binary(t), do: t
  defp entity_display_name(e), do: e.id

  defp entity_emoji("npc"), do: "🧙"
  defp entity_emoji("location"), do: "📍"
  defp entity_emoji("faction"), do: "⚔️"
  defp entity_emoji("stat-block"), do: "📖"
  defp entity_emoji("map"), do: "🗺"
  defp entity_emoji(_), do: "📄"

  # ── Render ──────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="flex flex-col bg-base-200" style="height: 100dvh">
      <%!-- Runner header --%>
      <div class="flex items-center gap-3 px-4 py-2 bg-base-300 border-b border-base-300 shrink-0">
        <.link navigate={"/entities/session/#{@session_id}"}
               class="btn btn-ghost btn-sm btn-circle">
          <.icon name="hero-arrow-left" class="size-5" />
        </.link>
        <span class="font-semibold text-sm truncate"><%= @session.title %></span>
      </div>

      <%!-- Content area --%>
      <div class="flex-1 overflow-hidden">
        <%= case @mode do %>
          <% :plan -> %> <%= render_plan(assigns) %>
          <% :map -> %> <%= render_map(assigns) %>
          <% :audio -> %> <%= render_audio(assigns) %>
        <% end %>
      </div>

      <%!-- Bottom nav --%>
      <nav class="flex shrink-0 bg-base-300 border-t border-base-300"
           style="padding-bottom: env(safe-area-inset-bottom, 0)">
        <%= for {mode, label, icon} <- [{:plan, "Plan", "📋"}, {:map, "Map", "🗺"}, {:audio, "Audio", "🎵"}] do %>
          <button phx-click="set_mode" phx-value-mode={mode}
                  class={["flex-1 flex flex-col items-center py-3 gap-0.5 text-xs font-medium transition-colors",
                          if(@mode == mode,
                            do: "text-primary border-t-2 border-primary -mt-px",
                            else: "text-base-content/60 hover:text-base-content")]}>
            <span class="text-xl leading-none"><%= icon %></span>
            <span><%= label %></span>
          </button>
        <% end %>
      </nav>
    </div>
    """
  end

  # ── Plan mode ───────────────────────────────────────────────────────────────

  defp render_plan(assigns) do
    ~H"""
    <div class="flex flex-col h-full relative">
      <div class="px-4 py-3 border-b border-base-300 shrink-0">
        <p class="text-xs text-base-content/50">
          Scene <%= @scene_index + 1 %> of <%= max(1, length(@scenes)) %>
        </p>
      </div>

      <%= if @scenes == [] do %>
        <div class="flex-1 flex items-center justify-center text-base-content/40">
          <p>No scenes planned yet. Open the planner to add scenes.</p>
        </div>
      <% else %>
        <% scene = Enum.at(@scenes, @scene_index) %>
        <div class="flex-1 overflow-y-auto px-4 py-4">
          <div class="flex items-center gap-3 mb-4">
            <button phx-click="prev_scene"
                    class={["btn btn-circle btn-sm btn-ghost",
                            if(@scene_index == 0, do: "btn-disabled opacity-30", else: "")]}>
              ◀
            </button>
            <h3 class="flex-1 text-center font-bold text-lg"><%= scene["title"] %></h3>
            <button phx-click="next_scene"
                    class={["btn btn-circle btn-sm btn-ghost",
                            if(@scene_index >= length(@scenes) - 1, do: "btn-disabled opacity-30", else: "")]}>
              ▶
            </button>
          </div>

          <%= if scene["notes"] && scene["notes"] != "" do %>
            <div class="prose max-w-none mb-4">
              <%= Phoenix.HTML.raw(Markdown.render(scene["notes"] || "")) %>
            </div>
          <% end %>

          <%= if scene["entity_ids"] && scene["entity_ids"] != [] do %>
            <div class="space-y-2">
              <%= for ref <- scene["entity_ids"] do %>
                <% [type, id] = case String.split(ref, ":", parts: 2) do
                     [t, i] -> [t, i]
                     _ -> ["", ""]
                   end %>
                <% entity = if type != "", do: Entities.get_entity(type, id), else: nil %>
                <%= if entity do %>
                  <% expanded = MapSet.member?(@expanded_entities, ref) %>
                  <div>
                    <button phx-click="toggle_entity" phx-value-ref={ref}
                            class={["badge badge-lg gap-1 cursor-pointer w-full justify-start transition-colors",
                                    if(expanded, do: "badge-primary", else: "badge-outline")]}>
                      <span><%= entity_emoji(type) %></span>
                      <span class="truncate"><%= entity_display_name(entity) %></span>
                      <span class={["ml-auto transition-transform text-xs",
                                    if(expanded, do: "rotate-180", else: "")]}>▼</span>
                    </button>
                    <%= if expanded do %>
                      <div class="card bg-base-100 shadow mt-1">
                        <div class="card-body py-3 px-4">
                          <p class="font-semibold text-sm"><%= entity_display_name(entity) %></p>
                          <%= if entity.body_html && entity.body_html != "" do %>
                            <div class="prose prose-sm max-w-none">
                              <%= Phoenix.HTML.raw(entity.body_html) %>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Notes FAB --%>
      <button phx-click="open_notes"
              class="fixed bottom-20 right-4 btn btn-primary btn-circle shadow-lg z-10 text-xl">
        📝
      </button>

      <%!-- Notes bottom sheet --%>
      <%= if @notes_open do %>
        <div class="fixed inset-0 bg-black/40 z-20" phx-click="close_notes"></div>
        <div class="fixed bottom-0 left-0 right-0 bg-base-100 rounded-t-2xl shadow-2xl p-4 z-30"
             style="padding-bottom: max(1rem, env(safe-area-inset-bottom))">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-semibold">Session Notes</h3>
            <button phx-click="close_notes" class="btn btn-ghost btn-sm btn-circle">✕</button>
          </div>
          <form phx-submit="save_notes">
            <textarea name="notes" rows="5"
                      class="textarea textarea-bordered w-full mb-3"
                      placeholder="Notes are appended to the session file with a timestamp..."><%= @notes %></textarea>
            <div class="flex justify-end gap-2">
              <button type="button" phx-click="close_notes" class="btn btn-ghost btn-sm">Cancel</button>
              <button type="submit" class="btn btn-primary btn-sm">Save</button>
            </div>
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Map mode ────────────────────────────────────────────────────────────────

  defp render_map(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <div class="flex items-center gap-2 px-3 py-2 bg-base-200/90 backdrop-blur border-b border-base-300 shrink-0 flex-wrap">
        <form phx-change="set_map" class="contents">
          <select name="map_id" class="select select-bordered select-sm min-w-0 max-w-40">
            <option value="">Select map...</option>
            <%= for map <- @session_maps do %>
              <option value={map.id} selected={@server_state.current_map == map.id}>
                <%= map.name %>
              </option>
            <% end %>
          </select>
        </form>

        <div class="flex items-center gap-1">
          <.icon name="hero-paint-brush" class="size-4 opacity-60" />
          <input type="range" id="brush-radius" min="0" max="8" value="0"
                 class="range range-xs range-primary w-20" />
        </div>

        <%!-- Brush / Eraser toggle --%>
        <div class="join">
          <button phx-click="set_fog_mode" phx-value-mode="brush"
                  class={["join-item btn btn-xs", if(@fog_mode == :brush, do: "btn-primary", else: "btn-ghost")]}>
            🖌 Brush
          </button>
          <button phx-click="set_fog_mode" phx-value-mode="eraser"
                  class={["join-item btn btn-xs", if(@fog_mode == :eraser, do: "btn-primary", else: "btn-ghost")]}>
            ⬜ Eraser
          </button>
        </div>

        <%!-- Map-wide actions --%>
        <button phx-click="hide_all" class="btn btn-xs btn-ghost" title="Cover entire map in fog">
          🌑 Cover
        </button>
        <button phx-click="reveal_all" class="btn btn-xs btn-ghost" title="Disable fog of war">
          ☀️ Clear
        </button>

        <%!-- QR code toggle --%>
        <button phx-click="toggle_player_qr"
                class={["btn btn-xs", if(@server_state.show_player_qr, do: "btn-primary", else: "btn-ghost")]}>
          📱 QR
        </button>

        <%!-- Clear all player drawings --%>
        <button phx-click="clear_all_drawings" class="btn btn-xs btn-ghost">
          🗑 Drawings
        </button>
      </div>

      <div class="flex-1 relative overflow-hidden bg-black">
        <%= if @server_state.current_map do %>
          <% map_entity = Enum.find(@session_maps, &(&1.id == @server_state.current_map)) %>
          <img id="map-bg"
               src={"/maps/assets/#{if map_entity && map_entity.asset_path && map_entity.asset_path != "", do: Path.basename(map_entity.asset_path), else: @server_state.current_map <> ".png"}"}
               class="absolute inset-0 w-full h-full object-contain" />
          <canvas id="fog-editor"
            data-session-id={@session_id}
            data-cell-size="20"
            data-grid-cols={@server_state.grid_cols}
            data-grid-rows={@server_state.grid_rows}
            data-fog-mode={@fog_mode}
            phx-hook="FogEditor"
            class="absolute inset-0 w-full h-full cursor-crosshair touch-none">
          </canvas>
        <% else %>
          <div class="absolute inset-0 flex items-center justify-center text-white/40">
            <div class="text-center">
              <.icon name="hero-map" class="size-16 mx-auto mb-3 opacity-30" />
              <p>Select a map from the dropdown above</p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ── Audio mode ──────────────────────────────────────────────────────────────

  defp render_audio(assigns) do
    ~H"""
    <div class="overflow-y-auto h-full px-4 py-4 space-y-6">
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/50 mb-3">Volume</h3>
        <form phx-change="set_volume" class="space-y-3">
          <%= for {label, key, val} <- [
            {"Master", "master", @server_state.audio_state.volume.master},
            {"Ambient", "ambient", @server_state.audio_state.volume.ambient},
            {"SFX", "sfx", @server_state.audio_state.volume.sfx}
          ] do %>
            <div class="flex items-center gap-3">
              <span class="text-sm w-16 shrink-0"><%= label %></span>
              <input type="range" name={key} min="0" max="100" value={val}
                     class="range range-primary range-sm flex-1" />
              <span class="text-sm w-10 text-right text-base-content/60"><%= val %>%</span>
            </div>
          <% end %>
        </form>
      </div>

      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/50 mb-3">Ambient</h3>
        <ul class="space-y-1">
          <%= for track <- @music do %>
            <% playing = @server_state.audio_state.ambient == track.path %>
            <li class={["flex items-center gap-2 px-3 py-2 rounded-lg transition-colors",
                        if(playing, do: "bg-primary/10 text-primary", else: "hover:bg-base-200")]}>
              <button phx-click={if playing, do: "stop_ambient", else: "play_ambient"}
                      phx-value-path={track.path}
                      class="flex-1 flex items-center gap-2 text-left text-sm">
                <span class="text-base"><%= if playing, do: "■", else: "▶" %></span>
                <span class="truncate"><%= track.name %></span>
              </button>
              <%= if playing do %>
                <button phx-click="stop_ambient" class="btn btn-ghost btn-xs">Stop</button>
              <% end %>
            </li>
          <% end %>
          <%= if @music == [] do %>
            <li class="text-base-content/40 text-sm px-3 py-2">
              No audio files in ~/campaign/audio/music/
            </li>
          <% end %>
        </ul>
      </div>

      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider text-base-content/50 mb-3">SFX</h3>
        <%= for {section, sfx_list} <- Enum.group_by(@sfx, & &1.section) do %>
          <div class="mb-4">
            <p class="text-xs text-base-content/40 uppercase tracking-wider mb-2"><%= section %></p>
            <div class="flex flex-wrap gap-2">
              <%= for sfx <- sfx_list do %>
                <button phx-click="play_sfx" phx-value-path={sfx.path}
                        class="btn btn-sm bg-base-300 hover:bg-primary hover:text-primary-content border-0 transition-colors">
                  <%= sfx.name %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
        <%= if @sfx == [] do %>
          <p class="text-base-content/40 text-sm">No SFX in ~/campaign/audio/sfx/</p>
        <% end %>
      </div>
    </div>
    """
  end
end
