defmodule DungeonCaster.Entities.TypeMeta do
  @moduledoc false

  @icons %{
    "npc" => "hero-user-group",
    "location" => "hero-map-pin",
    "faction" => "hero-shield-check",
    "session" => "hero-calendar-days",
    "stat-block" => "hero-book-open",
    "map" => "hero-map",
    "audio" => "hero-speaker-wave"
  }

  def icon(type) when is_binary(type), do: Map.get(@icons, type, "hero-link")
  def icon(_), do: "hero-link"
end
