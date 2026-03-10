defmodule DungeonCasterWeb.EntityEditorLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities
  alias DungeonCasterWeb.EntityHelpers

  def mount(%{"type" => type, "id" => id}, _session, socket) do
    Phoenix.PubSub.subscribe(DungeonCaster.PubSub, "entities:#{type}")
    entity = Entities.get_entity!(type, id)
    content = File.read!(entity.file_path)
    {:ok,
     assign(socket,
       entity: entity,
       type: type,
       content: content,
       flash_msg: nil,
       page_title: "Edit #{entity.name}"
     )}
  end

  def handle_event("save", %{"content" => content}, socket) do
    campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir) |> Path.expand()
    file_path = socket.assigns.entity.file_path |> Path.expand()

    if String.starts_with?(file_path, campaign_dir) do
      File.write!(file_path, content)
      {:noreply, assign(socket, content: content, flash_msg: "Saved — re-indexing...")}
    else
      {:noreply, put_flash(socket, :error, "Invalid file path")}
    end
  end

  def handle_event("open_entity_popover", %{"ref" => ref}, socket) do
    case EntityHelpers.entity_popover_data(ref) do
      {:ok, data} ->
        {:noreply, push_event(socket, "entity:popover-open", data)}
      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("search_entities", %{"q" => q}, socket) do
    results = EntityHelpers.search_entities(q)
    {:reply, %{results: results}, socket}
  end

  def handle_info({:updated, id}, socket) when id == socket.assigns.entity.id do
    {:noreply, assign(socket, flash_msg: "Re-indexed ✓")}
  end
  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <div class="flex justify-between items-center mb-4">
        <.link navigate={"/entities/#{@type}/#{@entity.id}"} class="text-sm text-gray-500">
          ← <%= @entity.name %>
        </.link>
        <h2 class="text-xl font-semibold">Edit <%= @type %></h2>
      </div>
      <%= if @flash_msg do %>
        <p class="mb-2 text-green-600 text-sm"><%= @flash_msg %></p>
      <% end %>
      <form phx-submit="save">
        <div id="entity-raw-editor" phx-hook="EntityEditor" phx-update="ignore">
          <textarea name="content" rows="40"
                    class="w-full font-mono text-sm border rounded p-3"><%= @content %></textarea>
        </div>
        <button type="submit"
                class="mt-2 px-4 py-2 bg-blue-600 text-white rounded">
          Save
        </button>
      </form>
    </div>
    """
  end
end
