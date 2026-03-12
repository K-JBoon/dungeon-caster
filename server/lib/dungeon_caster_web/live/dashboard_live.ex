defmodule DungeonCasterWeb.DashboardLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities

  @entity_types ~w(npc location faction session stat-block map audio)

  @type_meta %{
    "npc" => %{label: "NPCs", icon: "hero-user-group", color: "text-blue-500"},
    "location" => %{label: "Locations", icon: "hero-map-pin", color: "text-green-500"},
    "faction" => %{label: "Factions", icon: "hero-shield-check", color: "text-purple-500"},
    "session" => %{label: "Sessions", icon: "hero-calendar-days", color: "text-orange-500"},
    "stat-block" => %{label: "Stat Blocks", icon: "hero-book-open", color: "text-red-500"},
    "map" => %{label: "Maps", icon: "hero-map", color: "text-teal-500"},
    "audio" => %{label: "Audio", icon: "hero-speaker-wave", color: "text-amber-500"}
  }

  def mount(_params, _session, socket) do
    counts =
      Enum.map(@entity_types, fn type ->
        {type, length(Entities.list_entities(type))}
      end)

    {:ok, assign(socket, counts: counts, type_meta: @type_meta, page_title: "Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Dashboard</h1>
        <.link navigate="/entities/session/new" class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> New Session
        </.link>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
        <%= for {type, count} <- @counts do %>
          <% meta = @type_meta[type] %>
          <.link
            navigate={"/entities/#{type}"}
            class="card bg-base-100 shadow hover:shadow-md transition-shadow cursor-pointer"
          >
            <div class="card-body p-4">
              <div class="flex items-start justify-between">
                <.icon name={meta.icon} class={"size-8 #{meta.color}"} />
                <span class="text-3xl font-bold text-base-content/80">{count}</span>
              </div>
              <p class="text-sm font-medium mt-2">{meta.label}</p>
            </div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end
end
