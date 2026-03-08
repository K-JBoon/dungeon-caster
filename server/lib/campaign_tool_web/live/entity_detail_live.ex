defmodule CampaignToolWeb.EntityDetailLive do
  use CampaignToolWeb, :live_view
  alias CampaignTool.Entities

  def mount(%{"type" => type, "id" => id}, _session, socket) do
    Phoenix.PubSub.subscribe(CampaignTool.PubSub, "entities:#{type}")
    entity = Entities.get_entity!(type, id)
    {:ok, assign(socket, entity: entity, type: type, page_title: entity.name)}
  end

  def handle_info({:updated, id}, socket) when id == socket.assigns.entity.id do
    entity = Entities.get_entity!(socket.assigns.type, id)
    {:noreply, assign(socket, entity: entity, page_title: entity.name)}
  end
  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <div class="flex justify-between items-start mb-4">
        <div>
          <.link navigate={"/entities/#{@type}"} class="text-sm text-gray-500">
            ← <%= String.replace(@type, "-", " ") %>s
          </.link>
          <h1 class="text-3xl font-bold mt-1"><%= @entity.name %></h1>
        </div>
        <.link navigate={"/entities/#{@type}/#{@entity.id}/edit"}
               class="px-3 py-1 bg-blue-600 text-white rounded text-sm">
          Edit
        </.link>
      </div>
      <div class="prose max-w-none">
        <%= Phoenix.HTML.raw(@entity.body_html || "") %>
      </div>
    </div>
    """
  end
end
