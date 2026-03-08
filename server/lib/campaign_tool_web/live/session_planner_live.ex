defmodule CampaignToolWeb.SessionPlannerLive do
  use CampaignToolWeb, :live_view
  alias CampaignTool.{Entities, Session.Server}

  def mount(%{"id" => id}, _session, socket) do
    session = Entities.get_entity!("session", id)
    scenes = decode_scenes(session.scenes)
    {:ok,
     assign(socket,
       session: session,
       scenes: scenes,
       selected_scene_id: nil,
       entity_search: "",
       search_results: [],
       page_title: "Plan: #{session.title}"
     )}
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  def handle_event("add_scene", _, socket) do
    new_scene = %{
      "id" => "scene-#{System.unique_integer([:positive])}",
      "title" => "New Scene",
      "notes" => "",
      "entity_ids" => []
    }
    scenes = socket.assigns.scenes ++ [new_scene]
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes, selected_scene_id: new_scene["id"])}
  end

  def handle_event("select_scene", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_scene_id: id)}
  end

  def handle_event("update_scene", %{"title" => title, "notes" => notes}, socket) do
    scenes =
      Enum.map(socket.assigns.scenes, fn s ->
        if s["id"] == socket.assigns.selected_scene_id,
          do: Map.merge(s, %{"title" => title, "notes" => notes}),
          else: s
      end)
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes)}
  end

  def handle_event("search_entities", %{"q" => q}, socket) when byte_size(q) > 1 do
    results = Entities.search(q) |> Enum.take(8)
    {:noreply, assign(socket, search_results: results, entity_search: q)}
  end
  def handle_event("search_entities", _, socket) do
    {:noreply, assign(socket, search_results: [], entity_search: "")}
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
        if s["id"] == socket.assigns.selected_scene_id do
          Map.put(s, "entity_ids", List.delete(s["entity_ids"] || [], ref))
        else
          s
        end
      end)
    save_scenes(socket.assigns.session, scenes)
    {:noreply, assign(socket, scenes: scenes)}
  end

  def handle_event("go_live", _, socket) do
    session_id = socket.assigns.session.id
    case Registry.lookup(CampaignTool.Session.Registry, session_id) do
      [] -> Server.start_link(session_id)
      _ -> :ok
    end
    {:noreply, push_navigate(socket, to: "/sessions/#{session_id}/run")}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp decode_scenes(nil), do: []
  defp decode_scenes(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end
  defp decode_scenes(list) when is_list(list), do: list

  defp save_scenes(session, scenes) do
    case File.read(session.file_path) do
      {:ok, content} ->
        encoded = Jason.encode!(scenes)
        updated = replace_frontmatter_field(content, "scenes", encoded)
        File.write!(session.file_path, updated)
      {:error, _} ->
        :ok
    end
  end

  defp replace_frontmatter_field("---\n" <> rest, field, value) do
    case String.split(rest, "\n---\n", parts: 2) do
      [fm, body] ->
        lines = String.split(fm, "\n")
        key = field <> ":"
        updated_lines =
          if Enum.any?(lines, &String.starts_with?(&1, key)) do
            Enum.map(lines, fn line ->
              if String.starts_with?(line, key), do: "#{field}: #{Jason.encode!(value)}", else: line
            end)
          else
            lines ++ ["#{field}: #{Jason.encode!(value)}"]
          end
        "---\n" <> Enum.join(updated_lines, "\n") <> "\n---\n" <> body
      _ ->
        "---\n" <> rest
    end
  end
  defp replace_frontmatter_field(content, _, _), do: content

  # ── Render ───────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div style="display:flex; height:100vh; font-family:sans-serif; overflow:hidden">

      <%!-- Left: scene list --%>
      <div style="width:220px; border-right:1px solid #ddd; display:flex; flex-direction:column; padding:1rem; overflow-y:auto">
        <h3 style="font-size:1rem; font-weight:bold; margin-bottom:0.5rem"><%= @session.title %></h3>
        <div style="margin-bottom:0.75rem; display:flex; gap:0.5rem; flex-wrap:wrap">
          <button phx-click="go_live"
                  style="padding:6px 10px; background:#16a34a; color:white; border:none; border-radius:4px; cursor:pointer; font-size:0.8rem">
            ▶ Go Live
          </button>
        </div>
        <button phx-click="add_scene"
                style="width:100%; padding:6px; background:#3b82f6; color:white; border:none; border-radius:4px; cursor:pointer; margin-bottom:0.5rem; font-size:0.85rem">
          + Add Scene
        </button>
        <ul style="list-style:none; padding:0; margin:0">
          <%= for scene <- @scenes do %>
            <li phx-click="select_scene" phx-value-id={scene["id"]}
                style={"padding:6px 8px; border-radius:4px; cursor:pointer; font-size:0.85rem; margin-bottom:2px; #{if @selected_scene_id == scene["id"], do: "background:#dbeafe; font-weight:600", else: "hover:background:#f3f4f6"}"}>
              <%= scene["title"] %>
            </li>
          <% end %>
        </ul>
      </div>

      <%!-- Center: scene editor --%>
      <div style="flex:1; padding:1rem; overflow-y:auto; display:flex; flex-direction:column">
        <%= if scene = Enum.find(@scenes, &(&1["id"] == @selected_scene_id)) do %>
          <form phx-change="update_scene" style="display:flex; flex-direction:column; gap:0.5rem; margin-bottom:1rem">
            <input name="title" value={scene["title"]}
                   phx-debounce="500"
                   style="font-size:1.1rem; font-weight:bold; padding:6px; border:1px solid #ddd; border-radius:4px" />
            <textarea name="notes" rows="16" phx-debounce="800"
                      style="font-family:monospace; font-size:0.9rem; padding:8px; border:1px solid #ddd; border-radius:4px; resize:vertical"><%= scene["notes"] %></textarea>
          </form>

          <%!-- Entity link search --%>
          <div style="margin-bottom:0.75rem">
            <form phx-change="search_entities">
              <input name="q" value={@entity_search} phx-debounce="300"
                     placeholder="Link entity (search)..."
                     style="width:100%; padding:6px; border:1px solid #ddd; border-radius:4px; font-size:0.85rem" />
            </form>
            <%= if @search_results != [] do %>
              <ul style="margin-top:4px; border:1px solid #ddd; border-radius:4px; list-style:none; padding:0">
                <%= for r <- @search_results do %>
                  <li style="padding:6px 8px; border-bottom:1px solid #f3f4f6; display:flex; justify-content:space-between; align-items:center">
                    <span style="font-size:0.85rem"><strong><%= r.type %></strong>: <%= r.name %></span>
                    <button phx-click="link_entity" phx-value-ref={"#{r.type}:#{r.id}"}
                            style="font-size:0.75rem; padding:2px 8px; background:#3b82f6; color:white; border:none; border-radius:3px; cursor:pointer">
                      Link
                    </button>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>

          <%!-- Linked entities --%>
          <%= if scene["entity_ids"] && scene["entity_ids"] != [] do %>
            <div style="display:flex; flex-wrap:wrap; gap:4px">
              <%= for ref <- scene["entity_ids"] do %>
                <span style="background:#f0f9ff; border:1px solid #bae6fd; border-radius:12px; padding:2px 10px; font-size:0.8rem; display:flex; align-items:center; gap:4px">
                  <%= ref %>
                  <button phx-click="unlink_entity" phx-value-ref={ref}
                          style="background:none; border:none; cursor:pointer; color:#64748b; font-size:0.8rem">x</button>
                </span>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <p style="color:#94a3b8; margin-top:2rem; text-align:center">
            <%= if @scenes == [] do %>
              No scenes yet. Click "Add Scene" to start planning.
            <% else %>
              Select a scene from the left to edit it.
            <% end %>
          </p>
        <% end %>
      </div>

      <%!-- Right: sidebar --%>
      <div style="width:180px; border-left:1px solid #ddd; padding:1rem; overflow-y:auto">
        <h4 style="font-size:0.85rem; font-weight:bold; margin-bottom:0.5rem">Session Info</h4>
        <p style="font-size:0.8rem; color:#64748b">
          #<%= @session.session_number %> · <%= @session.status %>
        </p>
        <p style="font-size:0.8rem; color:#64748b; margin-top:0.5rem">
          <%= length(@scenes) %> scene(s)
        </p>
      </div>

    </div>
    """
  end
end
