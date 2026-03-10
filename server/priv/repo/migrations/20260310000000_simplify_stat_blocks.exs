defmodule DungeonCaster.Repo.Migrations.SimplifyStatBlocks do
  use Ecto.Migration

  def change do
    alter table(:stat_blocks) do
      remove :cr
      remove :size
      remove :creature_type
      remove :source
      remove :hp
      remove :ac
      remove :tags
    end
  end
end
