defmodule DungeonCasterWeb.SessionPlannerLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.{Entities, Session.Server, Audio}
  alias DungeonCaster.Markdown
  alias DungeonCaster.Sync.RevisionHistory
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
       music: music,
       revision_history: empty_revision_history(),
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

    {:noreply,
     assign(socket,
       scenes: scenes,
       selected_scene_id: new_scene["id"],
       linked_entities: collect_linked_entities(socket.assigns.session, scenes)
     )}
  end

  def handle_event("select_scene", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_scene_id: id)}
  end

  def handle_event("delete_scene", %{"id" => id}, socket) do
    scenes = Enum.reject(socket.assigns.scenes, &(&1["id"] == id))
    save_scenes(socket.assigns.session, scenes)

    new_selected =
      if socket.assigns.selected_scene_id == id,
        do: (List.first(scenes) || %{})["id"],
        else: socket.assigns.selected_scene_id

    {:noreply,
     assign(socket,
       scenes: scenes,
       selected_scene_id: new_selected,
       linked_entities: collect_linked_entities(socket.assigns.session, scenes)
     )}
  end

  def handle_event("reorder_scenes", %{"ids" => ids}, socket) do
    scenes = socket.assigns.scenes

    ordered =
      Enum.map(ids, fn id -> Enum.find(scenes, &(&1["id"] == id)) end)
      |> Enum.reject(&is_nil/1)

    save_scenes(socket.assigns.session, ordered)

    {:noreply,
     assign(socket,
       scenes: ordered,
       linked_entities: collect_linked_entities(socket.assigns.session, ordered)
     )}
  end

  def handle_event("update_scene", %{"title" => title, "notes" => notes}, socket) do
    scenes =
      Enum.map(socket.assigns.scenes, fn s ->
        if s["id"] == socket.assigns.selected_scene_id,
          do: Map.merge(s, %{"title" => title, "notes" => notes}),
          else: s
      end)

    save_scenes(socket.assigns.session, scenes)

    {:noreply,
     assign(socket,
       scenes: scenes,
       linked_entities: collect_linked_entities(socket.assigns.session, scenes)
     )}
  end

  def handle_event("open_revision_history", _, socket) do
    case current_scene(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a scene first")}

      scene ->
        {:noreply,
         open_revision_history(
           socket,
           socket.assigns.session.file_path,
           {:scene_notes, scene["id"]},
           "Scene History: #{scene["title"]}"
         )}
    end
  end

  def handle_event("close_revision_history", _, socket) do
    {:noreply, assign(socket, revision_history: empty_revision_history())}
  end

  def handle_event("select_revision", %{"sha" => sha}, socket) do
    case current_scene(socket) do
      nil -> {:noreply, socket}
      scene -> {:noreply, select_revision(socket, sha, {:scene_notes, scene["id"]})}
    end
  end

  def handle_event("restore_revision", %{"sha" => sha}, socket) do
    case current_scene(socket) do
      nil ->
        {:noreply, socket}

      scene ->
        mode = {:scene_notes, scene["id"]}

        case RevisionHistory.read_file_revision(socket.assigns.session.file_path, sha) do
          {:ok, content} ->
            notes = RevisionHistory.extract_editor_content(content, mode)

            scenes =
              Enum.map(socket.assigns.scenes, fn current ->
                if current["id"] == scene["id"],
                  do: Map.put(current, "notes", notes),
                  else: current
              end)

            save_scenes(socket.assigns.session, scenes)

            socket =
              socket
              |> assign(
                scenes: scenes,
                linked_entities: collect_linked_entities(socket.assigns.session, scenes),
                revision_history: empty_revision_history()
              )
              |> push_event("entity_editor:set_content", %{
                id: "scene-notes-#{scene["id"]}",
                content: notes
              })

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not restore that revision")}
        end
    end
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
    {:reply, %{results: results}, socket}
  end

  def handle_event("search_entities", _, socket) do
    {:reply, %{results: []}, socket}
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

      {:error, _} ->
        :ok
    end
  end

  defp collect_linked_entities(session, scenes) do
    # New-style: ~[Name]{type:id} refs in body and scene notes
    sources = [session.body_raw || ""] ++ Enum.map(scenes, &(&1["notes"] || ""))
    from_refs = Enum.flat_map(sources, &Markdown.extract_entity_refs/1)

    # Migration shim: old frontmatter ID list fields (npc_ids, stat_block_ids, etc.)
    frontmatter_refs =
      [
        {"npc", session.npc_ids || []},
        {"location", session.location_ids || []},
        {"faction", session.faction_ids || []},
        {"stat-block", session.stat_block_ids || []},
        {"map", session.map_ids || []}
      ]
      |> Enum.flat_map(fn {type, ids} ->
        Enum.map(ids, fn id -> %{type: type, id: id, display_name: id} end)
      end)

    (from_refs ++ frontmatter_refs)
    |> Enum.uniq_by(fn %{type: t, id: id} -> {t, id} end)
    |> Enum.map(fn %{type: type, id: id} = ref ->
      entity = Entities.get_entity(type, id)

      if entity do
        name = Map.get(entity, :name) || Map.get(entity, :title) || id
        Map.merge(ref, %{entity: entity, display_name: name})
      end
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
            Enum.map(lines, fn l ->
              if String.starts_with?(l, key), do: "#{field}: #{value}", else: l
            end)
          else
            lines ++ ["#{field}: #{value}"]
          end

        "---\n" <> Enum.join(updated, "\n") <> "\n---\n" <> body

      _ ->
        "---\n" <> rest
    end
  end

  defp replace_frontmatter_field(content, _, _), do: content

  defp open_revision_history(socket, file_path, mode, title) do
    case RevisionHistory.list_file_revisions(file_path) do
      {:ok, [first | _] = revisions} ->
        preview = load_revision_preview(file_path, first.sha, mode)

        assign(socket,
          revision_history: %{
            open: true,
            title: title,
            mode: mode,
            file_path: file_path,
            revisions: Enum.map(revisions, &decorate_revision/1),
            selected_sha: first.sha,
            preview: preview
          }
        )

      {:ok, []} ->
        put_flash(socket, :error, "No committed revisions found yet")

      {:error, _reason} ->
        put_flash(socket, :error, "Could not load revision history")
    end
  end

  defp select_revision(socket, sha, mode) do
    preview = load_revision_preview(socket.assigns.session.file_path, sha, mode)

    assign(socket,
      revision_history: %{
        socket.assigns.revision_history
        | selected_sha: sha,
          preview: preview
      }
    )
  end

  defp load_revision_preview(file_path, sha, mode) do
    case RevisionHistory.read_file_revision(file_path, sha) do
      {:ok, content} -> RevisionHistory.extract_editor_content(content, mode)
      {:error, _reason} -> "Unable to load this revision."
    end
  end

  defp decorate_revision(revision) do
    Map.merge(revision, %{
      display_time: format_revision_time(revision.committed_at),
      display_range_end: format_revision_time(revision.oldest_at)
    })
  end

  defp format_revision_time(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")
  end

  defp empty_revision_history do
    %{
      open: false,
      title: nil,
      mode: nil,
      file_path: nil,
      revisions: [],
      selected_sha: nil,
      preview: ""
    }
  end

  defp current_scene(socket) do
    Enum.find(socket.assigns.scenes, &(&1["id"] == socket.assigns.selected_scene_id))
  end

  # ── Render ───────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="flex overflow-hidden" style="height: 100%">
      <%!-- Left: scene list --%>
      <div class="w-60 shrink-0 border-r border-base-300 flex flex-col overflow-hidden">
        <div class="p-3 border-b border-base-300 flex items-center justify-between gap-2">
          <div class="min-w-0">
            <p class="font-semibold text-sm truncate">{@session.title}</p>
            <p class="text-xs text-base-content/50">#{@session.session_number}</p>
          </div>
          <button phx-click="go_live" class="btn btn-success btn-xs shrink-0">▶ Live</button>
        </div>
        <div class="p-2">
          <button phx-click="add_scene" class="btn btn-primary btn-sm w-full">+ Add Scene</button>
        </div>
        <ul id="scene-list" phx-hook="SortableScenes" class="flex-1 overflow-y-auto p-2 space-y-1">
          <%= for scene <- @scenes do %>
            <li
              data-scene-id={scene["id"]}
              draggable="true"
              class={[
                "group flex items-center gap-1 rounded-lg cursor-grab transition-colors",
                if(@selected_scene_id == scene["id"],
                  do: "bg-primary/10 text-primary",
                  else: "hover:bg-base-200"
                )
              ]}
            >
              <button
                phx-click="select_scene"
                phx-value-id={scene["id"]}
                class="flex-1 text-left px-3 py-2 text-sm truncate"
              >
                {scene["title"]}
              </button>
              <button
                phx-click="delete_scene"
                phx-value-id={scene["id"]}
                class="px-2 py-2 opacity-0 group-hover:opacity-100 text-error text-xs rounded hover:bg-error/10 transition-opacity"
              >
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
              <div class="flex items-center gap-2">
                <input
                  name="title"
                  value={scene["title"]}
                  phx-debounce="500"
                  class="input input-ghost w-full text-lg font-semibold focus:bg-base-200"
                />
                <button
                  type="button"
                  phx-click="open_revision_history"
                  class="btn btn-ghost btn-sm shrink-0"
                >
                  History
                </button>
              </div>
            </div>
            <div
              id={"scene-notes-#{scene["id"]}"}
              phx-hook="EntityEditor"
              phx-update="ignore"
              class="flex-1 flex flex-col min-h-0"
            >
              <textarea
                name="notes"
                phx-debounce="800"
                class="flex-1 w-full font-mono text-sm p-3 resize-none bg-transparent focus:outline-none"
                placeholder="Scene notes (Markdown)..."
              ><%= scene["notes"] %></textarea>
            </div>
          </form>
        <% else %>
          <div class="flex-1 flex items-center justify-center text-base-content/40">
            <div class="text-center">
              <.icon name="hero-document-text" class="size-12 mx-auto mb-3 opacity-30" />
              <p>{if @scenes == [], do: "Click 'Add Scene' to start.", else: "Select a scene."}</p>
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
            {"Link entities inline with ~[Name]{type:id} in the body or scene notes."}
          </p>
        <% else %>
          <%= for {type, items} <- grouped do %>
            <div>
              <h4 class="text-xs uppercase tracking-wider text-base-content/50 mb-2">
                {String.replace(type, "-", " ") |> String.capitalize()}s
              </h4>
              <ul class="space-y-1">
                <%= for %{entity: entity, display_name: label} <- items do %>
                  <li class="text-xs truncate">
                    <.link
                      navigate={"/entities/#{type}/#{entity.id}"}
                      class="hover:text-primary transition-colors"
                    >
                      {label}
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
                  <span class={
                    if asset_exists?(campaign_dir, track), do: "text-success", else: "text-error"
                  }>
                    {if asset_exists?(campaign_dir, track), do: "✓", else: "✗"}
                  </span>
                  <span class="truncate">{track.name}</span>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>

      <.revision_history_modal history={@revision_history} />
    </div>
    """
  end
end
