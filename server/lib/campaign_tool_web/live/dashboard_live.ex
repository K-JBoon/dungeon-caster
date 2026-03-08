defmodule CampaignToolWeb.DashboardLive do
  use CampaignToolWeb, :live_view
  alias CampaignTool.Entities

  @entity_types ~w(npc location faction session stat-block map)

  def mount(_params, _session, socket) do
    counts =
      Enum.map(@entity_types, fn type ->
        {type, length(Entities.list_entities(type))}
      end)
    {:ok, assign(socket, counts: counts, page_title: "Campaign Tool")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-6">Campaign Tool</h1>
      <ul class="space-y-2">
        <%= for {type, count} <- @counts do %>
          <li>
            <.link navigate={"/entities/#{type}"}
                  class="flex justify-between p-3 bg-white rounded shadow hover:bg-gray-50">
              <span class="capitalize"><%= String.replace(type, "-", " ") %>s</span>
              <span class="text-gray-500"><%= count %></span>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end
