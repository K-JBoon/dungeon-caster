defmodule DungeonCasterWeb.EntityFormLive do
  use DungeonCasterWeb, :live_view
  alias DungeonCaster.Entities
  alias DungeonCaster.Markdown
  alias DungeonCaster.Sync.RevisionHistory
  alias DungeonCasterWeb.EntityHelpers

  @type_dirs %{
    "npc" => "npcs",
    "location" => "locations",
    "faction" => "factions",
    "session" => "sessions",
    "stat-block" => "stat-blocks",
    "map" => "maps"
  }

  def mount(%{"type" => type, "id" => id}, _session, socket) do
    entity = Entities.get_entity!(type, id)
    content = File.read!(entity.file_path)
    {_fm, body} = split_content(content)

    socket =
      socket
      |> assign(
        mode: :edit,
        type: type,
        entity: entity,
        body: body,
        form_data: entity_to_form_data(type, entity),
        preview_tab: :edit,
        flash_msg: nil,
        revision_history: empty_revision_history(),
        page_title: "Edit #{entity_name(entity)}"
      )
      |> allow_upload(:asset,
        accept: ~w(.jpg .jpeg .png .webp .gif),
        max_entries: 1,
        max_file_size: 20_000_000
      )

    {:ok, socket}
  end

  def mount(%{"type" => type}, _session, socket) do
    socket =
      socket
      |> assign(
        mode: :new,
        type: type,
        entity: nil,
        body: "",
        form_data: default_fields(type),
        preview_tab: :edit,
        flash_msg: nil,
        revision_history: empty_revision_history(),
        page_title: "New #{String.replace(type, "-", " ") |> String.capitalize()}"
      )
      |> allow_upload(:asset,
        accept: ~w(.jpg .jpeg .png .webp .gif),
        max_entries: 1,
        max_file_size: 20_000_000
      )

    {:ok, socket}
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  def handle_event("set_preview_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, preview_tab: String.to_existing_atom(tab))}
  end

  def handle_event("validate", %{"entity" => %{"body" => body}}, socket) do
    {:noreply, assign(socket, body: body)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
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

  def handle_event("open_revision_history", _, %{assigns: %{mode: :new}} = socket) do
    {:noreply, put_flash(socket, :error, "History is available after the first save")}
  end

  def handle_event("open_revision_history", _, socket) do
    {:noreply,
     open_revision_history(socket, socket.assigns.entity.file_path, :body, "Body History")}
  end

  def handle_event("close_revision_history", _, socket) do
    {:noreply, assign(socket, revision_history: empty_revision_history())}
  end

  def handle_event("select_revision", %{"sha" => sha}, socket) do
    {:noreply, select_revision(socket, sha, :body)}
  end

  def handle_event("restore_revision", %{"sha" => sha}, socket) do
    case RevisionHistory.read_file_revision(socket.assigns.entity.file_path, sha) do
      {:ok, content} ->
        body = RevisionHistory.extract_editor_content(content, :body)

        socket =
          socket
          |> assign(body: body, preview_tab: :edit, revision_history: empty_revision_history())
          |> push_event("entity_editor:set_content", %{id: "entity-body-editor", content: body})

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not restore that revision")}
    end
  end

  def handle_event("save", %{"entity" => params}, socket) do
    type = socket.assigns.type
    campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir) |> Path.expand()

    uploaded_path =
      consume_uploaded_entries(socket, :asset, fn %{path: tmp_path}, entry ->
        asset_dir = Path.join([campaign_dir, @type_dirs[type], "assets"])
        File.mkdir_p!(asset_dir)
        dest = Path.join(asset_dir, entry.client_name)
        File.cp!(tmp_path, dest)
        {:ok, Path.join(["assets", entry.client_name])}
      end)
      |> List.first()

    params =
      if uploaded_path do
        asset_key = if type == "map", do: "asset_path", else: "portrait"
        Map.put(params, asset_key, uploaded_path)
      else
        params
      end

    body = socket.assigns.body
    fields = Map.drop(params, ["body"])

    case socket.assigns.mode do
      :new -> create_entity(socket, type, campaign_dir, fields, body)
      :edit -> update_entity(socket, type, campaign_dir, fields, body)
    end
  end

  # ── Create / Update ─────────────────────────────────────────────────────────

  defp create_entity(socket, type, campaign_dir, fields, body) do
    name = Map.get(fields, "name") || Map.get(fields, "title") || "untitled"
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    dir = @type_dirs[type]
    file_path = Path.join([campaign_dir, dir, "#{slug}.md"])

    content = build_file_content(type, slug, fields, body)
    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, content)

    attrs = fields_to_db_attrs(type, slug, fields, body, file_path)
    Entities.upsert_entity(type, attrs)

    {:noreply, push_navigate(socket, to: "/entities/#{type}/#{slug}")}
  end

  defp update_entity(socket, type, campaign_dir, fields, body) do
    entity = socket.assigns.entity
    file_path = entity.file_path |> Path.expand()

    if String.starts_with?(file_path, campaign_dir) do
      content = build_file_content(type, entity.id, fields, body)
      File.write!(file_path, content)
      attrs = fields_to_db_attrs(type, entity.id, fields, body, file_path)
      Entities.upsert_entity(type, attrs)
      {:noreply, push_navigate(socket, to: "/entities/#{type}/#{entity.id}")}
    else
      {:noreply, put_flash(socket, :error, "Invalid file path")}
    end
  end

  # ── File content builders ────────────────────────────────────────────────────

  defp build_file_content(type, id, fields, body) do
    fm_lines = ["---", "type: #{type}", "id: #{id}"] ++ fields_to_yaml(type, fields) ++ ["---"]
    Enum.join(fm_lines, "\n") <> "\n" <> body
  end

  defp fields_to_yaml("npc", fields) do
    [
      "name: #{fields["name"] || ""}",
      "status: #{fields["status"] || "alive"}",
      "role: #{fields["role"] || "unknown"}",
      "race: #{fields["race"] || ""}",
      "class: #{fields["class"] || ""}"
    ] ++
      maybe_list_field("faction_ids", fields["faction_ids"]) ++
      maybe_field("portrait", fields["portrait"]) ++
      maybe_field("stat_block_id", fields["stat_block_id"])
  end

  defp fields_to_yaml("location", fields) do
    [
      "name: #{fields["name"] || ""}",
      "location_type: #{fields["location_type"] || "city"}"
    ] ++
      maybe_list_field("faction_ids", fields["faction_ids"])
  end

  defp fields_to_yaml("faction", fields) do
    [
      "name: #{fields["name"] || ""}",
      "status: #{fields["status"] || "active"}"
    ] ++
      maybe_list_field("member_ids", fields["member_ids"])
  end

  defp fields_to_yaml("stat-block", fields) do
    ["name: #{fields["name"] || ""}"]
  end

  defp fields_to_yaml("map", fields) do
    [
      "name: #{fields["name"] || ""}",
      "map_type: #{fields["map_type"] || "battle"}",
      "asset_path: #{fields["asset_path"] || ""}"
    ]
  end

  defp fields_to_yaml("session", fields) do
    [
      "title: #{fields["title"] || ""}",
      "session_number: #{fields["session_number"] || "1"}",
      "status: #{fields["status"] || "planned"}"
    ]
  end

  defp fields_to_yaml(_, fields), do: ["name: #{fields["name"] || ""}"]

  defp maybe_field(_, nil), do: []
  defp maybe_field(_, ""), do: []
  defp maybe_field(key, val), do: ["#{key}: #{val}"]

  defp maybe_list_field(_, nil), do: []
  defp maybe_list_field(_, ""), do: []

  defp maybe_list_field(key, vals) when is_list(vals) and vals != [] do
    items = Enum.map_join(vals, "", &"\n  - #{&1}")
    ["#{key}:#{items}"]
  end

  defp maybe_list_field(key, str) when is_binary(str) do
    vals = str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    maybe_list_field(key, vals)
  end

  defp maybe_list_field(_, _), do: []

  # ── DB attrs builders ────────────────────────────────────────────────────────

  defp fields_to_db_attrs("npc", id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "name" => fields["name"] || "",
      "status" => fields["status"] || "alive",
      "role" => fields["role"] || "unknown",
      "race" => fields["race"],
      "class" => fields["class"],
      "faction_ids" => parse_list(fields["faction_ids"]),
      "portrait" => fields["portrait"],
      "stat_block_id" => fields["stat_block_id"],
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path,
      "tags" => []
    }
  end

  defp fields_to_db_attrs("location", id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "name" => fields["name"] || "",
      "location_type" => fields["location_type"] || "city",
      "faction_ids" => parse_list(fields["faction_ids"]),
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path,
      "tags" => []
    }
  end

  defp fields_to_db_attrs("faction", id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "name" => fields["name"] || "",
      "status" => fields["status"] || "active",
      "member_ids" => parse_list(fields["member_ids"]),
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path,
      "tags" => []
    }
  end

  defp fields_to_db_attrs("stat-block", id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "name" => fields["name"] || "",
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path
    }
  end

  defp fields_to_db_attrs("map", id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "name" => fields["name"] || "",
      "map_type" => fields["map_type"] || "battle",
      "asset_path" => fields["asset_path"] || "",
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path,
      "tags" => []
    }
  end

  defp fields_to_db_attrs("session", id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "title" => fields["title"] || "",
      "session_number" => parse_int(fields["session_number"]) || 1,
      "status" => fields["status"] || "planned",
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path,
      "tags" => [],
      "npc_ids" => [],
      "location_ids" => [],
      "map_ids" => [],
      "stat_block_ids" => [],
      "faction_ids" => []
    }
  end

  defp fields_to_db_attrs(type, id, fields, body, file_path) do
    html = Markdown.render(body)

    %{
      "id" => id,
      "name" => fields["name"] || "",
      "type" => type,
      "body_raw" => body,
      "body_html" => html,
      "file_path" => file_path
    }
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp default_fields("npc"), do: %{"status" => "alive", "role" => "unknown"}
  defp default_fields("location"), do: %{"location_type" => "city"}
  defp default_fields("faction"), do: %{"status" => "active"}
  defp default_fields("stat-block"), do: %{}
  defp default_fields("map"), do: %{"map_type" => "battle"}
  defp default_fields("session"), do: %{"session_number" => "1", "status" => "planned"}
  defp default_fields(_), do: %{}

  defp entity_to_form_data("npc", e) do
    %{
      "name" => e.name,
      "status" => e.status,
      "role" => e.role,
      "race" => e.race,
      "class" => e.class,
      "faction_ids" => Enum.join(e.faction_ids || [], ", "),
      "portrait" => e.portrait,
      "stat_block_id" => e.stat_block_id
    }
  end

  defp entity_to_form_data("location", e) do
    %{
      "name" => e.name,
      "location_type" => e.location_type,
      "faction_ids" => Enum.join(e.faction_ids || [], ", ")
    }
  end

  defp entity_to_form_data("faction", e) do
    %{"name" => e.name, "status" => e.status, "member_ids" => Enum.join(e.member_ids || [], ", ")}
  end

  defp entity_to_form_data("stat-block", e) do
    %{"name" => e.name}
  end

  defp entity_to_form_data("map", e) do
    %{"name" => e.name, "map_type" => e.map_type, "asset_path" => e.asset_path}
  end

  defp entity_to_form_data("session", e) do
    %{"title" => e.title, "session_number" => to_string(e.session_number), "status" => e.status}
  end

  defp entity_to_form_data(_, e), do: %{"name" => e.name}

  defp split_content("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [_fm, body] -> {"", String.trim_leading(body)}
      _ -> {"", ""}
    end
  end

  defp split_content(content), do: {"", content}

  defp parse_list(nil), do: []
  defp parse_list(list) when is_list(list), do: list

  defp parse_list(str) when is_binary(str) do
    str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(n) when is_integer(n), do: n

  defp entity_name(%{name: n}) when is_binary(n), do: n
  defp entity_name(%{title: t}) when is_binary(t), do: t
  defp entity_name(e), do: e.id

  defp back_path(type, nil), do: "/entities/#{type}"
  defp back_path(type, entity), do: "/entities/#{type}/#{entity.id}"

  defp render_preview(body) do
    Markdown.render(body)
  end

  # ── Render ───────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-4xl mx-auto">
      <div class="flex items-center gap-3 mb-6">
        <.link navigate={back_path(@type, @entity)} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" />
        </.link>
        <h1 class="text-xl font-bold">
          {if @mode == :new, do: "New", else: "Edit"}
          {String.replace(@type, "-", " ") |> String.capitalize()}
        </h1>
      </div>

      <form phx-submit="save" phx-change="validate">
        <%!-- Structured fields --%>
        <div class="card bg-base-100 shadow mb-4">
          <div class="card-body gap-4">
            <h3 class="font-semibold text-sm uppercase tracking-wider opacity-60">Details</h3>
            {render_fields(@type, assigns)}
          </div>
        </div>

        <%!-- Markdown body --%>
        <div class="card bg-base-100 shadow mb-4">
          <div class="card-body gap-0 p-0">
            <div class="flex border-b border-base-300">
              <button
                type="button"
                phx-click="set_preview_tab"
                phx-value-tab="edit"
                class={[
                  "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
                  if(@preview_tab == :edit,
                    do: "border-primary text-primary",
                    else: "border-transparent"
                  )
                ]}
              >
                Markdown
              </button>
              <button
                type="button"
                phx-click="set_preview_tab"
                phx-value-tab="preview"
                class={[
                  "px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
                  if(@preview_tab == :preview,
                    do: "border-primary text-primary",
                    else: "border-transparent"
                  )
                ]}
              >
                Preview
              </button>
              <div class="ml-auto px-3 py-2">
                <button type="button" phx-click="open_revision_history" class="btn btn-ghost btn-sm">
                  History
                </button>
              </div>
            </div>
            <%= if @preview_tab == :edit do %>
              <div id="entity-body-editor" phx-hook="EntityEditor" phx-update="ignore">
                <textarea
                  name="entity[body]"
                  rows="20"
                  class="w-full font-mono text-sm p-4 bg-transparent focus:outline-none resize-y"
                  placeholder="Body content in Markdown..."
                ><%= @body %></textarea>
              </div>
            <% else %>
              <div class="prose max-w-none p-4 min-h-40">
                {Phoenix.HTML.raw(render_preview(@body))}
              </div>
            <% end %>
          </div>
        </div>

        <div class="flex justify-end gap-3">
          <.link navigate={back_path(@type, @entity)} class="btn btn-ghost">Cancel</.link>
          <button type="submit" class="btn btn-primary">
            {if @mode == :new, do: "Create", else: "Save Changes"}
          </button>
        </div>
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

  defp render_fields("npc", assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <label class="form-control col-span-2 md:col-span-1">
        <div class="label"><span class="label-text">Name *</span></div>
        <input name="entity[name]" value={@form_data["name"]} class="input input-bordered" required />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Status</span></div>
        <select name="entity[status]" class="select select-bordered">
          <%= for s <- ~w(alive dead unknown) do %>
            <option value={s} selected={@form_data["status"] == s}>{s}</option>
          <% end %>
        </select>
      </label>
      <label class="form-control col-span-2 md:col-span-1">
        <div class="label"><span class="label-text">Role</span></div>
        <input name="entity[role]" value={@form_data["role"]} class="input input-bordered" />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Race</span></div>
        <input name="entity[race]" value={@form_data["race"]} class="input input-bordered" />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Class</span></div>
        <input name="entity[class]" value={@form_data["class"]} class="input input-bordered" />
      </label>
      <label class="form-control col-span-2">
        <div class="label">
          <span class="label-text">Faction IDs</span>
          <span class="label-text-alt">comma-separated slugs</span>
        </div>
        <input
          name="entity[faction_ids]"
          value={@form_data["faction_ids"]}
          class="input input-bordered"
          placeholder="e.g. thieves-guild, city-watch"
        />
      </label>
      <label class="form-control col-span-2">
        <div class="label"><span class="label-text">Portrait</span></div>
        <%= if @form_data["portrait"] do %>
          <img
            src={"/maps/assets/#{@form_data["portrait"]}"}
            class="size-20 rounded-full object-cover mb-2"
          />
        <% end %>
        <.live_file_input upload={@uploads.asset} class="file-input file-input-bordered w-full" />
      </label>
    </div>
    """
  end

  defp render_fields("location", assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <label class="form-control col-span-2 md:col-span-1">
        <div class="label"><span class="label-text">Name *</span></div>
        <input name="entity[name]" value={@form_data["name"]} class="input input-bordered" required />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Type</span></div>
        <select name="entity[location_type]" class="select select-bordered">
          <%= for t <- ~w(city town village dungeon wilderness temple ruins other) do %>
            <option value={t} selected={@form_data["location_type"] == t}>{t}</option>
          <% end %>
        </select>
      </label>
      <label class="form-control col-span-2">
        <div class="label">
          <span class="label-text">Faction IDs</span>
          <span class="label-text-alt">comma-separated</span>
        </div>
        <input
          name="entity[faction_ids]"
          value={@form_data["faction_ids"]}
          class="input input-bordered"
        />
      </label>
    </div>
    """
  end

  defp render_fields("faction", assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <label class="form-control col-span-2 md:col-span-1">
        <div class="label"><span class="label-text">Name *</span></div>
        <input name="entity[name]" value={@form_data["name"]} class="input input-bordered" required />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Status</span></div>
        <select name="entity[status]" class="select select-bordered">
          <%= for s <- ~w(active disbanded secret hostile) do %>
            <option value={s} selected={@form_data["status"] == s}>{s}</option>
          <% end %>
        </select>
      </label>
      <label class="form-control col-span-2">
        <div class="label">
          <span class="label-text">Member NPC IDs</span>
          <span class="label-text-alt">comma-separated</span>
        </div>
        <input
          name="entity[member_ids]"
          value={@form_data["member_ids"]}
          class="input input-bordered"
        />
      </label>
    </div>
    """
  end

  defp render_fields("stat-block", assigns) do
    ~H"""
    <label class="form-control">
      <div class="label"><span class="label-text">Name *</span></div>
      <input name="entity[name]" value={@form_data["name"]} class="input input-bordered" required />
    </label>
    """
  end

  defp render_fields("map", assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <label class="form-control col-span-2 md:col-span-1">
        <div class="label"><span class="label-text">Name *</span></div>
        <input name="entity[name]" value={@form_data["name"]} class="input input-bordered" required />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Type</span></div>
        <select name="entity[map_type]" class="select select-bordered">
          <%= for t <- ~w(battle regional world dungeon city) do %>
            <option value={t} selected={@form_data["map_type"] == t}>{t}</option>
          <% end %>
        </select>
      </label>
      <label class="form-control col-span-2">
        <div class="label"><span class="label-text">Map Image</span></div>
        <%= if @form_data["asset_path"] && @form_data["asset_path"] != "" do %>
          <img
            src={"/maps/assets/#{Path.basename(@form_data["asset_path"])}"}
            class="w-full max-h-40 object-contain rounded mb-2 bg-base-300"
          />
        <% end %>
        <.live_file_input upload={@uploads.asset} class="file-input file-input-bordered w-full" />
        <input type="hidden" name="entity[asset_path]" value={@form_data["asset_path"] || ""} />
      </label>
    </div>
    """
  end

  defp render_fields("session", assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <label class="form-control col-span-2">
        <div class="label"><span class="label-text">Title *</span></div>
        <input name="entity[title]" value={@form_data["title"]} class="input input-bordered" required />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Session #</span></div>
        <input
          name="entity[session_number]"
          type="number"
          min="1"
          value={@form_data["session_number"]}
          class="input input-bordered"
        />
      </label>
      <label class="form-control">
        <div class="label"><span class="label-text">Status</span></div>
        <select name="entity[status]" class="select select-bordered">
          <%= for s <- ~w(planned active complete) do %>
            <option value={s} selected={@form_data["status"] == s}>{s}</option>
          <% end %>
        </select>
      </label>
    </div>
    """
  end

  defp render_fields(_, assigns) do
    ~H"""
    <label class="form-control">
      <div class="label"><span class="label-text">Name *</span></div>
      <input name="entity[name]" value={@form_data["name"]} class="input input-bordered" required />
    </label>
    """
  end
end
