defmodule DungeonCaster.Repo do
  use Ecto.Repo,
    otp_app: :dungeon_caster,
    adapter: Ecto.Adapters.SQLite3
end
