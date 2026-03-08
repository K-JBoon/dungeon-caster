defmodule CampaignToolWeb.EntityBrowserLive do
  use CampaignToolWeb, :live_view
  alias CampaignTool.Entities

  def mount(%{"type" => type}, _session, socket) do
    Phoenix.PubSub.subscribe(CampaignTool.PubSub, "entities:#{type}")
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
    <div class="max-w-2xl mx-auto p-6">
      <.link navigate="/" class="text-sm text-gray-500">← Dashboard</.link>
      <h2 class="text-2xl font-bold mt-2 mb-4 capitalize">
        <%= String.replace(@type, "-", " ") %>s
      </h2>
      <form phx-submit="search" phx-change="search" class="mb-4">
        <input name="q" value={@q} phx-debounce="300"
               placeholder={"Search #{@type}s..."}
               class="w-full border rounded px-3 py-2" />
      </form>
      <ul class="space-y-1">
        <%= for e <- @entities do %>
          <li>
            <.link navigate={"/entities/#{@type}/#{e.id}"}
                  class="block p-2 hover:bg-gray-50 rounded">
              <%= e.name %>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
