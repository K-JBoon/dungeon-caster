defmodule DungeonCasterWeb.EntityBrowserLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities

  def mount(%{"type" => type}, _session, socket) do
    Phoenix.PubSub.subscribe(DungeonCaster.PubSub, "entities:#{type}")
    entities = Entities.list_entities(type)
    {:ok, assign(socket, type: type, entities: entities, q: "", page_title: "#{type}s")}
  end

  def handle_params(%{"q" => q}, _uri, socket) when byte_size(q) > 0 do
    results = Entities.search(q)
    {:noreply, assign(socket, entities: results, q: q)}
  end
  def handle_params(_params, _uri, socket) do
    entities = Entities.list_entities(socket.assigns.type)
    {:noreply, assign(socket, entities: entities, q: "")}
  end

  def handle_info({:updated, _id}, socket) do
    entities = Entities.list_entities(socket.assigns.type)
    {:noreply, assign(socket, entities: entities)}
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: "/entities/#{socket.assigns.type}?q=#{URI.encode(q)}")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-bold capitalize">
          <%= String.replace(@type, "-", " ") %>s
        </h2>
        <.link navigate={"/entities/#{@type}/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" />
          New <%= String.replace(@type, "-", " ") |> String.capitalize() %>
        </.link>
      </div>

      <form phx-submit="search" phx-change="search" class="mb-6">
        <label class="input input-bordered flex items-center gap-2 w-full max-w-md">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input name="q" value={@q} phx-debounce="300"
                 placeholder={"Search #{String.replace(@type, "-", " ")}s..."}
                 class="grow" />
        </label>
      </form>

      <%= if @entities == [] do %>
        <div class="text-center py-16 text-base-content/50">
          <.icon name="hero-inbox" class="size-12 mx-auto mb-3 opacity-30" />
          <p>No <%= String.replace(@type, "-", " ") %>s yet.</p>
          <.link navigate={"/entities/#{@type}/new"} class="btn btn-primary btn-sm mt-4">
            Create the first one
          </.link>
        </div>
      <% else %>
        <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          <%= for e <- @entities do %>
            <.link navigate={"/entities/#{@type}/#{e.id}"}
                   class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow">
              <div class="card-body p-4 gap-1">
                <%= render_card(@type, e, assigns) %>
                <p class="text-base-content/40 text-xs truncate mt-1">/<%= e.id %></p>
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_card("npc", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div class="flex items-start gap-2">
      <%= if @e.portrait do %>
        <img src={"/maps/assets/#{@e.portrait}"} class="size-10 rounded-full object-cover shrink-0" />
      <% else %>
        <div class="size-10 rounded-full bg-base-300 flex items-center justify-center shrink-0">
          <.icon name="hero-user" class="size-5 opacity-40" />
        </div>
      <% end %>
      <div class="min-w-0">
        <p class="font-medium text-sm truncate"><%= @e.name %></p>
        <div class="flex gap-1 mt-1 flex-wrap">
          <span class={["badge badge-xs", status_badge_class(@e.status)]}>
            <%= @e.status %>
          </span>
          <%= if @e.role && @e.role != "unknown" do %>
            <span class="badge badge-xs badge-ghost truncate max-w-[5rem]"><%= @e.role %></span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_card("location", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div>
      <div class="flex items-center gap-1 mb-1">
        <.icon name="hero-map-pin" class="size-4 text-green-500 shrink-0" />
        <p class="font-medium text-sm truncate"><%= @e.name %></p>
      </div>
      <span class="badge badge-xs badge-ghost"><%= @e.location_type %></span>
    </div>
    """
  end

  defp render_card("faction", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div>
      <div class="flex items-center gap-1 mb-1">
        <.icon name="hero-shield-check" class="size-4 text-purple-500 shrink-0" />
        <p class="font-medium text-sm truncate"><%= @e.name %></p>
      </div>
      <span class={["badge badge-xs", status_badge_class(@e.status)]}><%= @e.status %></span>
    </div>
    """
  end

  defp render_card("stat-block", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-1">
        <p class="font-medium text-sm truncate flex-1"><%= @e.name %></p>
        <span class="badge badge-xs badge-error ml-1">CR <%= @e.cr %></span>
      </div>
      <p class="text-xs text-base-content/60 truncate">
        <%= @e.size %> <%= @e.creature_type %>
      </p>
    </div>
    """
  end

  defp render_card("map", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div>
      <%= if @e.asset_path && @e.asset_path != "" do %>
        <img src={"/maps/assets/#{Path.basename(@e.asset_path)}"}
             class="w-full h-16 object-cover rounded mb-2" />
      <% else %>
        <div class="w-full h-16 bg-base-300 rounded mb-2 flex items-center justify-center">
          <.icon name="hero-map" class="size-6 opacity-30" />
        </div>
      <% end %>
      <p class="font-medium text-sm truncate"><%= @e.name %></p>
      <span class="badge badge-xs badge-ghost"><%= @e.map_type %></span>
    </div>
    """
  end

  defp render_card("session", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div>
      <div class="flex items-center gap-1 mb-1">
        <span class="badge badge-xs badge-outline">#<%= @e.session_number %></span>
      </div>
      <p class="font-medium text-sm truncate"><%= @e.title %></p>
      <span class={["badge badge-xs mt-1", session_status_class(@e.status)]}><%= @e.status %></span>
    </div>
    """
  end

  defp render_card(_, e, _assigns) do
    assigns = %{e: e}
    ~H"<p class='font-medium text-sm truncate'><%= @e.name %></p>"
  end

  defp status_badge_class("alive"), do: "badge-success"
  defp status_badge_class("active"), do: "badge-success"
  defp status_badge_class("dead"), do: "badge-error"
  defp status_badge_class(_), do: "badge-warning"

  defp session_status_class("active"), do: "badge-success"
  defp session_status_class("complete"), do: "badge-neutral"
  defp session_status_class(_), do: "badge-info"
end
