defmodule DungeonCaster.Entities.Schemas.Npc do
  use Ecto.Schema
  import Ecto.Changeset
  alias DungeonCaster.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "npcs" do
    field :name, :string
    field :status, :string
    field :role, :string
    field :race, :string
    field :class, :string
    field :level, :integer
    field :location_id, :string
    field :faction_ids, StringList
    field :portrait, :string
    field :stat_block_id, :string
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(npc, attrs) do
    npc
    |> cast(attrs, [
      :id,
      :name,
      :status,
      :role,
      :race,
      :class,
      :level,
      :location_id,
      :faction_ids,
      :portrait,
      :stat_block_id,
      :tags,
      :body_raw,
      :body_html,
      :file_path
    ])
    |> validate_required([:id, :name, :status, :role])
  end
end
