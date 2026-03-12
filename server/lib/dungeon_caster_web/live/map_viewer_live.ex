defmodule DungeonCasterWeb.MapViewerLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities

  def mount(%{"id" => id}, _session, socket) do
    map = Entities.get_entity!("map", id)
    # asset_path is like "maps/assets/filename.png"
    # We serve it at /maps/assets/filename.png
    image_url = "/" <> map.asset_path
    {:ok, assign(socket, map: map, image_url: image_url, page_title: map.name)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-6">
      <.link navigate="/entities/map" class="text-sm text-gray-500">← Maps</.link>
      <h2 class="text-2xl font-bold mt-2 mb-4">{@map.name}</h2>
      <div class="bg-gray-900 rounded p-2">
        <img src={@image_url} alt={@map.name} class="max-w-full rounded" />
      </div>
      <p class="mt-2 text-sm text-gray-500">
        Type: {@map.map_type} · Asset: {@map.asset_path}
      </p>
    </div>
    """
  end
end
