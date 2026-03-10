defmodule DungeonCasterWeb.SessionPlannerLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.{Entities, Session.Server, Audio}
  alias DungeonCaster.Markdown
  alias DungeonCasterWeb.EntityHelpers

  def mount(%{"id" => id}, _session, socket) do
    session = Entities.get_entity!("session", id)
    scenes = decode_scenes(session.scenes)
    linked_entities = collect_linked_entities(session, scenes)
    music = Audio.list_music()

    {:ok,
     assign(socket,
       session: session,
       scenes: scenes,
       linked_entities: linked_entities,
       selected_scene_id: (List.first(scenes) || %{})["id"],
       entity_search: "",
       search_results: [],
       popover_ref: nil,
       popover_entity: nil,
       music: music,
       page_title: "Plan: #{session.title}"
     )}
  end

  # ── Scene CRUD ──────────────────────────────────────────────────────────────

  def handle_event("add_scene", _, socket) do
    new_scene = %{
      "id" => "scene-#{System.unique_integer([:positive])}",
      "title" => "New Scene",
      "notes" => "",
      "entity_ids" => []
    }
    scenes = socket.assigns.scenes ++ [new_scene]
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes, selected_scene_id: new_scene["id"], linked_entities: collect_linked_entities(socket.assigns.session, scenes))}
  end

  def handle_event("select_scene", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_scene_id: id, entity_search: "", search_results: [], popover_ref: nil)}
  end

  def handle_event("delete_scene", %{"id" => id}, socket) do
    scenes = Enum.reject(socket.assigns.scenes, &(&1["id"] == id))
    save_scenes(socket.assigns.session, scenes)
    new_selected =
      if socket.assigns.selected_scene_id == id,
        do: (List.first(scenes) || %{})["id"],
        else: socket.assigns.selected_scene_id
    {:noreply, assign(socket, scenes: scenes, selected_scene_id: new_selected, linked_entities: collect_linked_entities(socket.assigns.session, scenes))}
  end

  def handle_event("reorder_scenes", %{"ids" => ids}, socket) do
    scenes = socket.assigns.scenes
    ordered = Enum.map(ids, fn id -> Enum.find(scenes, &(&1["id"] == id)) end)
              |> Enum.reject(&is_nil/1)
    save_scenes(socket.assigns.session, ordered)
    {:noreply, assign(socket, scenes: ordered, linked_entities: collect_linked_entities(socket.assigns.session, ordered))}
  end

  def handle_event("update_scene", %{"title" => title, "notes" => notes}, socket) do
    scenes =
      Enum.map(socket.assigns.scenes, fn s ->
        if s["id"] == socket.assigns.selected_scene_id,
          do: Map.merge(s, %{"title" => title, "notes" => notes}),
          else: s
      end)
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes, linked_entities: collect_linked_entities(socket.assigns.session, scenes))}
  end

  # ── Entity search / link ────────────────────────────────────────────────────

  def handle_event("open_entity_popover", %{"ref" => ref}, socket) do
    case EntityHelpers.entity_popover_data(ref) do
      {:ok, data} ->
        {:noreply, push_event(socket, "entity:popover-open", data)}
      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("search_entities", %{"q" => q}, socket) when byte_size(q) > 1 do
    results = EntityHelpers.search_entities(q)
    {:reply, %{results: results}, assign(socket, search_results: results, entity_search: q)}
  end

  def handle_event("search_entities", _, socket) do
    {:reply, %{results: []}, assign(socket, search_results: [], entity_search: "")}
  end

  def handle_event("link_entity", %{"ref" => ref}, socket) do
    scenes =
      Enum.map(socket.assigns.scenes, fn s ->
        if s["id"] == socket.assigns.selected_scene_id do
          ids = s["entity_ids"] || []
          Map.put(s, "entity_ids", Enum.uniq(ids ++ [ref]))
        else
          s
        end
      end)
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes, search_results: [], entity_search: "")}
  end

  def handle_event("unlink_entity", %{"ref" => ref}, socket) do
    scenes =
      Enum.map(socket.assigns.scenes, fn s ->
        if s["id"] == socket.assigns.selected_scene_id,
          do: Map.put(s, "entity_ids", List.delete(s["entity_ids"] || [], ref)),
          else: s
      end)
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes, popover_ref: nil, popover_entity: nil)}
  end

  def handle_event("show_popover", %{"ref" => ref}, socket) do
    if socket.assigns.popover_ref == ref do
      {:noreply, assign(socket, popover_ref: nil, popover_entity: nil)}
    else
      entity = load_entity_from_ref(ref)
      {:noreply, assign(socket, popover_ref: ref, popover_entity: entity)}
    end
  end

  def handle_event("go_live", _, socket) do
    session_id = socket.assigns.session.id
    case Registry.lookup(DungeonCaster.Session.Registry, session_id) do
      [] -> Server.start_link(session_id)
      _ -> :ok
    end
    {:noreply, push_navigate(socket, to: "/sessions/#{session_id}/run")}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp load_entity_from_ref(ref) do
    case String.split(ref, ":", parts: 2) do
      [type, id] ->
        case Entities.get_entity(type, id) do
          nil -> nil
          entity -> {type, entity}
        end
      _ -> nil
    end
  end

  defp entity_label(nil), do: "Unknown"
  defp entity_label({_, entity}) do
    Map.get(entity, :name) || Map.get(entity, :title) || entity.id
  end

  defp entity_icon("npc"), do: "hero-user"
  defp entity_icon("location"), do: "hero-map-pin"
  defp entity_icon("faction"), do: "hero-shield-check"
  defp entity_icon("stat-block"), do: "hero-book-open"
  defp entity_icon("map"), do: "hero-map"
  defp entity_icon(_), do: "hero-document"

  defp asset_exists?(campaign_dir, %{path: path}) when is_binary(path),
    do: File.exists?(Path.join(campaign_dir, path))
  defp asset_exists?(_, _), do: false

  defp decode_scenes(nil), do: []
  defp decode_scenes(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end
  defp decode_scenes(list) when is_list(list), do: list

  defp save_scenes(session, scenes) do
    encoded = Jason.encode!(scenes)
    Entities.update_session_scenes(session.id, encoded)
    case File.read(session.file_path) do
      {:ok, content} ->
        File.write!(session.file_path, replace_frontmatter_field(content, "scenes", encoded))
      {:error, _} -> :ok
    end
  end

  defp collect_linked_entities(session, scenes) do
    sources = [session.body_raw || ""] ++ Enum.map(scenes, &(&1["notes"] || ""))

    sources
    |> Enum.flat_map(&Markdown.extract_entity_refs/1)
    |> Enum.uniq_by(fn %{type: t, id: id} -> {t, id} end)
    |> Enum.map(fn %{type: type, id: id} = ref ->
      entity = Entities.get_entity(type, id)
      if entity, do: Map.put(ref, :entity, entity), else: nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp replace_frontmatter_field("---\n" <> rest, field, value) do
    case String.split(rest, "\n---\n", parts: 2) do
      [fm, body] ->
        key = field <> ":"
        lines = String.split(fm, "\n")
        updated =
          if Enum.any?(lines, &String.starts_with?(&1, key)) do
            Enum.map(lines, fn l -> if String.starts_with?(l, key), do: "#{field}: #{value}", else: l end)
          else
            lines ++ ["#{field}: #{value}"]
          end
        "---\n" <> Enum.join(updated, "\n") <> "\n---\n" <> body
      _ -> "---\n" <> rest
    end
  end
  defp replace_frontmatter_field(content, _, _), do: content

  # ── Render ───────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="flex overflow-hidden" style="height: 100%">

      <%!-- Left: scene list --%>
      <div class="w-60 shrink-0 border-r border-base-300 flex flex-col overflow-hidden">
        <div class="p-3 border-b border-base-300 flex items-center justify-between gap-2">
          <div class="min-w-0">
            <p class="font-semibold text-sm truncate"><%= @session.title %></p>
            <p class="text-xs text-base-content/50">#<%= @session.session_number %></p>
          </div>
          <button phx-click="go_live" class="btn btn-success btn-xs shrink-0">▶ Live</button>
        </div>
        <div class="p-2">
          <button phx-click="add_scene" class="btn btn-primary btn-sm w-full">+ Add Scene</button>
        </div>
        <ul id="scene-list" phx-hook="SortableScenes"
            class="flex-1 overflow-y-auto p-2 space-y-1">
          <%= for scene <- @scenes do %>
            <li data-scene-id={scene["id"]} draggable="true"
                class={["group flex items-center gap-1 rounded-lg cursor-grab transition-colors",
                        if(@selected_scene_id == scene["id"],
                          do: "bg-primary/10 text-primary",
                          else: "hover:bg-base-200")]}>
              <button phx-click="select_scene" phx-value-id={scene["id"]}
                      class="flex-1 text-left px-3 py-2 text-sm truncate">
                <%= scene["title"] %>
              </button>
              <button phx-click="delete_scene" phx-value-id={scene["id"]}
                      class="px-2 py-2 opacity-0 group-hover:opacity-100 text-error text-xs rounded hover:bg-error/10 transition-opacity">
                ✕
              </button>
            </li>
          <% end %>
        </ul>
      </div>

      <%!-- Center: scene editor --%>
      <div class="flex-1 flex flex-col overflow-hidden min-w-0">
        <%= if scene = Enum.find(@scenes, &(&1["id"] == @selected_scene_id)) do %>
          <form phx-change="update_scene" class="flex flex-col flex-1 overflow-hidden">
            <div class="p-3 border-b border-base-300 shrink-0">
              <input name="title" value={scene["title"]} phx-debounce="500"
                     class="input input-ghost w-full text-lg font-semibold focus:bg-base-200" />
            </div>
            <div id={"scene-notes-#{scene["id"]}"} phx-hook="EntityEditor" phx-update="ignore" class="flex-1 flex flex-col min-h-0">
              <textarea name="notes" phx-debounce="800"
                        class="flex-1 w-full font-mono text-sm p-3 resize-none bg-transparent focus:outline-none"
                        placeholder="Scene notes (Markdown)..."><%= scene["notes"] %></textarea>
            </div>
          </form>

          <%!-- Entity linking --%>
          <div class="p-3 border-t border-base-300 shrink-0">
            <form phx-change="search_entities" class="mb-2">
              <label class="input input-bordered input-sm flex items-center gap-2">
                <.icon name="hero-magnifying-glass" class="size-3 opacity-50" />
                <input name="q" value={@entity_search} phx-debounce="300"
                       placeholder="Link entity..." class="grow text-sm" />
              </label>
            </form>

            <%= if @search_results != [] do %>
              <ul class="border border-base-300 rounded-lg overflow-hidden shadow-md mb-2 max-h-48 overflow-y-auto">
                <%= for r <- @search_results do %>
                  <li class="flex items-center justify-between px-3 py-2 hover:bg-base-200 text-sm">
                    <span class="flex items-center gap-2 min-w-0">
                      <.icon name={entity_icon(r.type)} class="size-3.5 opacity-60 shrink-0" />
                      <span class="truncate"><%= r.name %></span>
                      <span class="text-base-content/40 text-xs shrink-0"><%= r.type %></span>
                    </span>
                    <button phx-click="link_entity" phx-value-ref={"#{r.type}:#{r.id}"}
                            class="btn btn-xs btn-primary ml-2 shrink-0">Link</button>
                  </li>
                <% end %>
              </ul>
            <% end %>

            <%!-- Linked entity pills --%>
            <%= if scene["entity_ids"] && scene["entity_ids"] != [] do %>
              <div class="flex flex-wrap gap-1">
                <%= for ref <- scene["entity_ids"] do %>
                  <% loaded = load_entity_from_ref(ref) %>
                  <div class="relative">
                    <span class={["badge badge-outline gap-1 cursor-pointer hover:badge-primary transition-colors",
                                  if(@popover_ref == ref, do: "badge-primary", else: "")]}>
                      <%= if loaded do %>
                        <% {type, _} = loaded %>
                        <.icon name={entity_icon(type)} class="size-3" />
                      <% end %>
                      <button phx-click="show_popover" phx-value-ref={ref} class="text-xs">
                        <%= entity_label(loaded) %>
                      </button>
                      <button phx-click="unlink_entity" phx-value-ref={ref}
                              class="ml-0.5 opacity-60 hover:opacity-100">✕</button>
                    </span>
                    <%!-- Popover --%>
                    <%= if @popover_ref == ref && @popover_entity do %>
                      <% {_t, ent} = @popover_entity %>
                      <div class="absolute bottom-full left-0 mb-2 w-64 bg-base-100 border border-base-300 rounded-xl shadow-xl p-3 z-50">
                        <button phx-click="show_popover" phx-value-ref={ref}
                                class="absolute top-2 right-2 btn btn-ghost btn-xs">✕</button>
                        <p class="font-semibold text-sm mb-1 pr-6">
                          <%= Map.get(ent, :name) || Map.get(ent, :title) %>
                        </p>
                        <%= if ent.body_html && ent.body_html != "" do %>
                          <div class="prose prose-xs max-w-none text-xs max-h-32 overflow-y-auto">
                            <%= Phoenix.HTML.raw(ent.body_html) %>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

        <% else %>
          <div class="flex-1 flex items-center justify-center text-base-content/40">
            <div class="text-center">
              <.icon name="hero-document-text" class="size-12 mx-auto mb-3 opacity-30" />
              <p><%= if @scenes == [], do: "Click 'Add Scene' to start.", else: "Select a scene." %></p>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Right: session assets sidebar --%>
      <div class="w-64 shrink-0 border-l border-base-300 overflow-y-auto p-3 space-y-5">
        <% campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir) |> Path.expand() %>

        <%!-- Linked entities from ~[...]{} refs in body and scene notes --%>
        <% grouped = Enum.group_by(@linked_entities, & &1.type) %>
        <%= if @linked_entities == [] do %>
          <p class="text-xs text-base-content/40 italic">
            <%= "Link entities inline with ~[Name]{type:id} in the body or scene notes." %>
          </p>
        <% else %>
          <%= for {type, items} <- grouped do %>
            <div>
              <h4 class="text-xs uppercase tracking-wider text-base-content/50 mb-2">
                <%= String.replace(type, "-", " ") |> String.capitalize() %>s
              </h4>
              <ul class="space-y-1">
                <%= for %{entity: entity, display_name: label} <- items do %>
                  <li class="text-xs truncate">
                    <.link navigate={"/entities/#{type}/#{entity.id}"}
                           class="hover:text-primary transition-colors">
                      <%= label %>
                    </.link>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        <% end %>

        <%!-- Audio --%>
        <div>
          <h4 class="text-xs uppercase tracking-wider text-base-content/50 mb-2">Audio</h4>
          <%= if @music == [] do %>
            <p class="text-xs text-base-content/40">No music files found.</p>
          <% else %>
            <ul class="space-y-1">
              <%= for track <- @music do %>
                <li class="flex items-center gap-2 text-xs">
                  <span class={if asset_exists?(campaign_dir, track), do: "text-success", else: "text-error"}>
                    <%= if asset_exists?(campaign_dir, track), do: "✓", else: "✗" %>
                  </span>
                  <span class="truncate"><%= track.name %></span>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>

    </div>
    """
  end
end
