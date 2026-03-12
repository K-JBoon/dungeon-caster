defmodule DungeonCasterWeb.EntityEditorLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities
  alias DungeonCaster.Sync.RevisionHistory
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
       revision_history: empty_revision_history(),
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

  def handle_event("open_revision_history", _, socket) do
    {:noreply,
     open_revision_history(socket, socket.assigns.entity.file_path, :raw, "Revision History")}
  end

  def handle_event("close_revision_history", _, socket) do
    {:noreply, assign(socket, revision_history: empty_revision_history())}
  end

  def handle_event("select_revision", %{"sha" => sha}, socket) do
    {:noreply, select_revision(socket, sha, :raw)}
  end

  def handle_event("restore_revision", %{"sha" => sha}, socket) do
    case RevisionHistory.read_file_revision(socket.assigns.entity.file_path, sha) do
      {:ok, content} ->
        socket =
          socket
          |> assign(
            content: content,
            revision_history: empty_revision_history(),
            flash_msg: "Revision loaded into editor"
          )
          |> push_event("entity_editor:set_content", %{id: "entity-raw-editor", content: content})

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not restore that revision")}
    end
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
          ← {@entity.name}
        </.link>
        <div class="flex items-center gap-2">
          <button type="button" phx-click="open_revision_history" class="btn btn-ghost btn-sm">
            History
          </button>
          <h2 class="text-xl font-semibold">Edit {@type}</h2>
        </div>
      </div>
      <%= if @flash_msg do %>
        <p class="mb-2 text-green-600 text-sm">{@flash_msg}</p>
      <% end %>
      <form phx-submit="save">
        <div id="entity-raw-editor" phx-hook="EntityEditor" phx-update="ignore">
          <textarea name="content" rows="40" class="w-full font-mono text-sm border rounded p-3"><%= @content %></textarea>
        </div>
        <button
          type="submit"
          class="mt-2 px-4 py-2 bg-blue-600 text-white rounded"
        >
          Save
        </button>
      </form>
      <.revision_history_modal history={@revision_history} />
    </div>
    """
  end

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
    preview = load_revision_preview(socket.assigns.entity.file_path, sha, mode)

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
end
