defmodule DungeonCasterWeb.EntityDetailLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities

  def mount(%{"type" => type, "id" => id}, _session, socket) do
    Phoenix.PubSub.subscribe(DungeonCaster.PubSub, "entities:#{type}")
    entity = Entities.get_entity!(type, id)
    {:ok, assign(socket, entity: entity, type: type, page_title: entity_name(entity))}
  end

  def handle_info({:updated, id}, socket) when id == socket.assigns.entity.id do
    entity = Entities.get_entity!(socket.assigns.type, id)
    {:noreply, assign(socket, entity: entity)}
  end
  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event("delete", _, socket) do
    entity = socket.assigns.entity
    type = socket.assigns.type
    campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir) |> Path.expand()
    file_path = entity.file_path |> Path.expand()

    if String.starts_with?(file_path, campaign_dir) do
      File.rm(file_path)
      Entities.delete_entity(type, entity.id)
      {:noreply, push_navigate(socket, to: "/entities/#{type}")}
    else
      {:noreply, put_flash(socket, :error, "Cannot delete: invalid path")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-4xl mx-auto">
      <div class="flex items-start justify-between mb-4">
        <div>
          <.link navigate={"/entities/#{@type}"}
                 class="text-sm text-base-content/60 hover:text-base-content">
            ← <%= String.replace(@type, "-", " ") |> String.capitalize() %>s
          </.link>
          <h1 class="text-2xl font-bold mt-1"><%= entity_name(@entity) %></h1>
        </div>
        <div class="flex gap-2 shrink-0">
          <.link navigate={"/entities/#{@type}/#{@entity.id}/edit"} class="btn btn-primary btn-sm">
            Edit
          </.link>
          <.link navigate={"/entities/#{@type}/#{@entity.id}/edit/raw"} class="btn btn-ghost btn-sm">
            Raw
          </.link>
          <button phx-click="delete"
                  data-confirm={"Delete #{entity_name(@entity)}? This cannot be undone."}
                  class="btn btn-error btn-sm btn-outline">
            Delete
          </button>
        </div>
      </div>

      <%!-- Metadata card --%>
      <div class="card bg-base-100 shadow mb-4">
        <div class="card-body py-4">
          <%= render_metadata(@type, @entity, assigns) %>
        </div>
      </div>

      <%!-- Body --%>
      <%= if @entity.body_html && @entity.body_html != "" do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body prose max-w-none">
            <%= Phoenix.HTML.raw(@entity.body_html) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_metadata("npc", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div class="flex gap-4 items-start">
      <%= if @e.portrait do %>
        <img src={"/maps/assets/#{@e.portrait}"} class="size-20 rounded-full object-cover shrink-0" />
      <% else %>
        <div class="size-20 rounded-full bg-base-300 flex items-center justify-center shrink-0">
          <.icon name="hero-user" class="size-8 opacity-30" />
        </div>
      <% end %>
      <div class="flex flex-wrap gap-2 items-center">
        <span class="badge badge-ghost"><%= @e.status %></span>
        <%= if @e.role, do: kv("Role", @e.role) %>
        <%= if @e.race, do: kv("Race", @e.race) %>
        <%= if @e.class, do: kv("Class", @e.class) %>
      </div>
    </div>
    """
  end

  defp render_metadata("stat-block", _e, _assigns) do
    assigns = %{}
    ~H"""
    <div></div>
    """
  end

  defp render_metadata("map", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div>
      <%= if @e.asset_path && @e.asset_path != "" do %>
        <img src={"/maps/assets/#{Path.basename(@e.asset_path)}"}
             class="w-full max-h-64 object-contain rounded mb-3 bg-base-300" />
      <% end %>
      <span class="badge badge-ghost"><%= @e.map_type %></span>
    </div>
    """
  end

  defp render_metadata("session", e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div class="flex flex-wrap gap-3 items-center">
      <span class="badge badge-outline">#<%= @e.session_number %></span>
      <span class="badge badge-ghost"><%= @e.status %></span>
      <.link navigate={"/sessions/#{@e.id}/plan"} class="btn btn-primary btn-sm ml-auto">
        Open Planner →
      </.link>
    </div>
    """
  end

  defp render_metadata(_, e, _assigns) do
    assigns = %{e: e}
    ~H"""
    <div class="flex flex-wrap gap-2">
      <%= if Map.get(@e, :status), do: kv("Status", @e.status) %>
    </div>
    """
  end

  defp kv(label, value) do
    assigns = %{label: label, value: value}
    ~H"""
    <div class="flex items-center gap-1">
      <span class="text-xs text-base-content/50"><%= @label %>:</span>
      <span class="text-sm font-medium"><%= @value %></span>
    </div>
    """
  end

  defp entity_name(%{name: n}) when is_binary(n), do: n
  defp entity_name(%{title: t}) when is_binary(t), do: t
  defp entity_name(e), do: Map.get(e, :id, "Unknown")
end
