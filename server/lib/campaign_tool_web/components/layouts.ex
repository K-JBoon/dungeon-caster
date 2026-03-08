defmodule CampaignToolWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CampaignToolWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-base-200">
      <%!-- Sidebar --%>
      <nav class="w-56 shrink-0 bg-base-300 flex flex-col gap-1 p-3 overflow-y-auto">
        <a href="/" class="flex items-center gap-2 px-2 py-3 mb-2">
          <span class="text-lg font-bold text-primary">Campaign Tool</span>
        </a>
        <p class="text-xs uppercase tracking-wider text-base-content/50 px-2 mb-1">Entities</p>
        <%= for {type, label, icon} <- [
          {"npc", "NPCs", "hero-user-group"},
          {"location", "Locations", "hero-map-pin"},
          {"faction", "Factions", "hero-shield-check"},
          {"stat-block", "Stat Blocks", "hero-book-open"},
          {"map", "Maps", "hero-map"}
        ] do %>
          <.link navigate={"/entities/#{type}"}
                 class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm hover:bg-base-100 transition-colors">
            <.icon name={icon} class="size-4 opacity-70" />
            <%= label %>
          </.link>
        <% end %>
        <div class="divider my-1" />
        <p class="text-xs uppercase tracking-wider text-base-content/50 px-2 mb-1">Sessions</p>
        <.link navigate="/entities/session"
               class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm hover:bg-base-100 transition-colors">
          <.icon name="hero-calendar-days" class="size-4 opacity-70" />
          Sessions
        </.link>
        <div class="mt-auto pt-4">
          <.theme_toggle />
        </div>
      </nav>

      <%!-- Main content --%>
      <main class="flex-1 overflow-y-auto">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
